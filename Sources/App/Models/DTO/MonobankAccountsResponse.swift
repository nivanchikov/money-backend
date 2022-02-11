import Vapor

enum AccountType: String, Content {
	case black
	case white
	case platinum
	case iron
	case fop
	case yellow
	case eAid
}

struct MonobankAccountsResponse: Content {
	let clientId: String
	let accounts: [MonobankAccountDTO]
}

struct MonobankAccountDTO: Content {
	let id: String
	let currencyCode: Int
	let balance: Int
	let creditLimit: Int
	let number: [String]
	let type: AccountType
	let iban: String

	enum CodingKeys: String, CodingKey {
		case id
		case currencyCode
		case balance
		case creditLimit
		case number = "maskedPan"
		case type
		case iban
	}
}

struct MonobankTransactionDTO: Content {
	let id: String
	let time: Date
	let description: String?

	let mcc: Int
	let originalMcc: Int

	// amount in card currency
	let amount: Int

	// operation amount
	let operationAmount: Int

	// operation currency
	let currencyCode: Int
	let commissionRate: Int
	let balance: Int
}

struct PrivatBankTransactionDTO: Content {
	let id: String
	let time: Date
	let description: String?

	// amount in card currency
	let amount: Int

	// operation amount
	let operationAmount: Int

	// operation currency
	let currencyCode: Int

	let commissionRate: Int
	let balance: Int
}

//<statement card="5363542308814897" appcode="549543" trandate="2021-11-17" trantime="11:38:00" amount="1000.00 UAH" cardamount="-1047.00 UAH" rest="-41243.87 UAH" terminal="DN00, CAHA9504" description="&#x421;&#x43D;&#x44F;&#x442;&#x438;&#x435; &#x43D;&#x430;&#x43B;&#x438;&#x447;&#x43D;&#x44B;&#x445; &#x432; &#x431;&#x430;&#x43D;&#x43A;&#x43E;&#x43C;&#x430;&#x442;&#x435;: METRO Cash-Carry, &#x425;&#x430;&#x440;&#x44C;&#x43A;&#x43E;&#x432;, &#x43F;&#x440;&#x43E;&#x441;&#x43F;. &#x413;&#x430;&#x433;&#x430;&#x440;&#x438;&#x43D;&#x430;, &#x434;. 187/1"/>
