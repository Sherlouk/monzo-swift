import Foundation

public final class Account {
    public enum `Type` {
        /// Monzo Prepaid Account
        case prepaid
        
        /// Monzo Current Account
        case current
        
        /// Unknown Account
        case unknown
        
        init(rawValue: String) {
            switch rawValue {
            case "uk_prepaid": self = .prepaid
            case "uk_retail": self = .current
            default: self = .unknown
            }
        }
    }
    
    // MARK: Variables
    
    /// The user the account belongs to
    let user: User
    
    /// The type of account (e.g. prepaid or current account)
    public let type: Type
    
    /// The account's unique identifier
    public let id: String
    
    /// The account's description
    public let description: String
    
    /// The date in which the account was created
    public let created: Date
    
    /// Private storage of webhooks
    private var _webhooks = [Webhook]()
    
    /// Whether or not webhooks been loaded from the API
    private var webhooksLoaded = false
    
    /// List of current webhooks on the account
    public var webhooks: [Webhook] {
        if !webhooksLoaded {
            do {
                try loadWebhooks()
                webhooksLoaded = true
            } catch {}
        }
        
        return _webhooks
    }
    
    // MARK: Initialiser
    
    init(user: User, type: Type, id: String, description: String, created: Date) {
        self.user = user
        self.type = type
        self.id = id
        self.description = description
        self.created = created
    }
    
    init(user: User, json: JSONObject) throws {
        self.user = user
        self.type = Type(rawValue: json["type"].stringValue)
        self.id = json["id"].stringValue
        self.description = json["description"].stringValue
        self.created = json["created"].iso8601Value
    }
    
    // MARK: Transactions
    
    public func transactions(limit: Int = 10) -> [Transaction] {
        return []
    }
    
    // MARK: Balance
    
    /// The current available balance of the account
    public func balance() throws -> Amount {
        let rawBalance = try user.client.provider.request(.balance(self))
        return Amount(rawBalance["balance"].int64Value, currency: rawBalance["currency"].stringValue)
    }
    
    /// The amount the account has spent today (Considered from approx. 4am onwards)
    public func spentToday() throws -> Amount {
        let rawBalance = try user.client.provider.request(.balance(self))
        return Amount(rawBalance["spend_today"].int64Value, currency: rawBalance["currency"].stringValue)
    }
    
    // MARK: Webhook
    
    private func loadWebhooks() throws {
        let rawWebhooks = try user.client.provider.requestArray(.webhooks(self))
        _webhooks = rawWebhooks.map({ Webhook(account: self, json: $0) })
    }
    
    public func addWebhook(url: URL) throws {
        let rawWebhook = try user.client.provider.request(.registerWebhook(self, url))
        _webhooks.append(Webhook(account: self, json: rawWebhook))
    }
    
    public func removeWebhook(_ webhook: Webhook) throws {
        try user.client.provider.deliver(.deleteWebhook(webhook))
        guard let index = _webhooks.index(where: { $0.id == webhook.id }) else { return }
        _webhooks.remove(at: index)
    }
}
