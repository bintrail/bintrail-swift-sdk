internal extension URL {
    static let bintrailBaseUrl = URL(string: "http://localhost:5000")!
}

public enum ClientError: Error {
    case appCredentialsMising // TODO: Rename, ingest token?
    case appCredentialsEncodingFailed

    case requestBodyEncodingFailed

    case urlSessionTaskError(Error)

    case invalidURLResponse
    case unexpectedResponseBody

    case unexpectedResponseStatus(Int)

    case `internal`(Error)

    case unexpected

    case uninitializedExecutableInfo
    case uninitializedDeviceInfo
}

internal class Client {
    internal struct Endpoint {
        let method: String
        let path: String
        let headers: [String: String]

        func url(withBaseUrl baseUrl: URL) -> URL {
            return baseUrl.appendingPathComponent(path)
        }

        static let sessionInit = Endpoint(
            method: "POST",
            path: "session/init",
            headers: [
                "Accept": "application/json",
                "Content-Type": "application/json"
            ]
        )

        static let putSessionEntries = Endpoint(
            method: "POST",
            path: "session/entries",
            headers: [
                "Accept": "application/json",
                "Content-Type": "application/json"
            ]
        )
    }

    internal struct Credentials {
        let keyId: String
        let secret: String

        init(keyId: String, secret: String) {
            self.keyId = keyId
            self.secret = secret
        }

        var base64EncodedString: String? {
            let string = keyId + ":" + secret
            return string.data(using: .utf8)?.base64EncodedString()
        }
    }

    internal var credentials: Credentials?

    private let dispatchQueue = DispatchQueue(label: "com.bintrail.client")

    private let urlSession = URLSession(configuration: .default)

    internal let baseUrl: URL

    internal init(baseUrl: URL) {
        self.baseUrl = baseUrl
    }
}

internal struct PutSessionEntriesRequest: Encodable {
    let logs: [Log]

    let events: [Event]

    let sessionId: String

    init<T: Sequence>(sessionId: String, entries: T) where T.Element == Session.Entry {
        var logs: [Log] = []
        var events: [Event] = []

        for entry in entries {
            switch entry {
            case .log(let entry):
                logs.append(entry)
            case .event(let entry):
                events.append(entry)
            }
        }

        self.sessionId = sessionId

        self.logs = logs
        self.events = events
    }
}

internal struct InitializeSessionRequest: Encodable {
    let executable: Executable?

    let device: Device?

    let startedAt: Date

    init(metadata: Session.Metadata) {
        executable = metadata.executable
        device = metadata.device
        startedAt = metadata.startedAt
    }
}

internal struct InitializeSessionResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case remoteIdentifier = "sessionId"
    }

    let remoteIdentifier: String
}

internal extension Client {
    func upload(
        sessionMetadata: Session.Metadata,
        completion: @escaping (Result<InitializeSessionResponse, ClientError>) -> Void
    ) {
        send(
            endpoint: .sessionInit,
            requestBody: InitializeSessionRequest(metadata: sessionMetadata),
            responseBody: InitializeSessionResponse.self
        ) { result in
            completion(
                result.map { _, body in
                    body
                }
            )
        }
    }

    func upload<T>(
        entries: T,
        forSessionWithRemoteIdentifier remoteIdentifier: String,
        completion: @escaping (Result<Void, ClientError>) -> Void
    ) where T: Sequence, T.Element == Session.Entry {
        dispatchQueue.async {
            do {
                let data = try JSONEncoder.bintrailDefault.encode(
                    PutSessionEntriesRequest(
                        sessionId: remoteIdentifier,
                        entries: entries
                    )
                )

                self.send(endpoint: .putSessionEntries, body: data) { result in
                    switch result {
                    case .success:
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            } catch {
                completion(.failure(.internal(error)))
            }
        }
    }

    private func send<T, U>(
        endpoint: Endpoint,
        requestBody: T,
        responseBody: U.Type,
        completion: @escaping (Result<(HTTPURLResponse, U), ClientError>) -> Void
    ) where T: Encodable, U: Decodable {
        dispatchQueue.async {
            do {
                self.send(endpoint: endpoint, body: try JSONEncoder.bintrailDefault.encode(requestBody)) { result in
                    do {
                        let (response, data) = try result.get()
                        completion(
                            .success((response, try JSONDecoder.bintrailDefault.decode(responseBody, from: data)))
                        )
                    } catch let error as ClientError {
                        completion(.failure(error))
                    } catch {
                        completion(.failure(.internal(error)))
                    }
                }
            } catch {
                completion(.failure(.internal(error)))
            }
        }
    }

    private func send(
        endpoint: Endpoint,
        body: Data?,
        completion: @escaping (Result<(HTTPURLResponse, Data), ClientError>) -> Void
    ) {
        dispatchQueue.async {
            do {
                var urlRequest = URLRequest(url: endpoint.url(withBaseUrl: self.baseUrl))
                urlRequest.httpMethod = endpoint.method

                for (key, value) in endpoint.headers {
                    urlRequest.setValue(value, forHTTPHeaderField: key)
                }

                guard let credentials = self.credentials else {
                    throw ClientError.appCredentialsMising
                }

                guard let base64EncodedAppCredentials = credentials.base64EncodedString else {
                    throw ClientError.appCredentialsEncodingFailed
                }

                urlRequest.setValue(base64EncodedAppCredentials, forHTTPHeaderField: "Bintrail-Ingest-Token")
                urlRequest.httpBody = body

                self.send(urlRequest: urlRequest, completion: completion)
            } catch let error as ClientError {
                completion(.failure(error))
            } catch {
                completion(.failure(.internal(error)))
            }
        }
    }

    private func send(
        urlRequest: URLRequest,
        completion: @escaping (Result<(HTTPURLResponse, Data), ClientError>) -> Void
    ) {
        bt_log_internal("Sending URLRequest", urlRequest)

        urlSession.dataTask(with: urlRequest) { data, urlResponse, error in
            do {
                if let error = error {
                    throw ClientError.urlSessionTaskError(error)
                }

                guard let httpUrlResponse = urlResponse as? HTTPURLResponse else {
                    throw ClientError.invalidURLResponse
                }

                guard (200 ..< 300).contains(httpUrlResponse.statusCode) else {
                    // TODO: Remove me
                    if let data = data, let string = String(data: data, encoding: .utf8) {
                        print(string)
                    }

                    throw ClientError.unexpectedResponseStatus(httpUrlResponse.statusCode)
                }

                completion(.success((httpUrlResponse, data ?? Data())))
            } catch let error as ClientError {
                completion(.failure(error))
            } catch {
                completion(.failure(.internal(error)))
            }
        }.resume()
    }
}
