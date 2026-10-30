import Foundation
import DokiCore

extension AppModel {
    func refreshAccount() async {
        accountGeneration += 1
        let generation = accountGeneration
        guard let hub = configuredHubURL, let token = DeviceCredentialStore.token(for: hub) else { accountStatus = nil; accountCollectionIDs = []; return }
        let client = HubAccountClient(hub: hub)
        let address = hubURLString
        do {
            let status = try await client.status(token: token)
            try Task.checkCancellation(); guard hubURLString == address, accountGeneration == generation else { return }
            accountStatus = status; accountError = nil
            if status.bangumi == nil { accountCollectionIDs = [] }
            if status.bangumi != nil {
                let entries = try await client.collections(token: token)
                try Task.checkCancellation(); guard hubURLString == address, accountGeneration == generation else { return }
                var ids = Set<String>()
                for entry in entries {
                    mergeCatalog(entry.subject)
                    let id = "bgm-\(entry.subject_id)"; ids.insert(id)
                    if followOverrides[id] == nil {
                        switch entry.type {
                        case 1: catalogSubjects[id]?.followState = .planned
                        case 2: catalogSubjects[id]?.followState = .completed
                        case 3: catalogSubjects[id]?.followState = .watching
                        case 5: catalogSubjects[id]?.followState = .dropped
                        default: catalogSubjects[id]?.followState = .paused
                        }
                    }
                }
                accountCollectionIDs = ids
                persistCatalog()
            }
        } catch is CancellationError { } catch {
            guard hubURLString == address, accountGeneration == generation else { return }
            accountError = (error as? any LocalizedError)?.errorDescription ?? "账号服务暂时不可用"
            if let error = error as? HubAccountError, error.status == 401 { accountStatus = nil; accountCollectionIDs = []; DeviceCredentialStore.clear(for: hub) }
        }
    }
}
