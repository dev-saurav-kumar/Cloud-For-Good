/**
 * Description        : Utility class to create test data (Accounts, Contacts, Opportunities) for test classes.
 * Author             : Saurav Kumar
 * Created Date       : 05-Nov-2026
 * Last Modified Date : 05-Nov-2026
 */
@isTest
public class TestDataFactory {

	public static List<Account> createAccounts(Integer count, Boolean doInsert) {
		List<Account> accList = new List<Account>();

		for (Integer i = 0; i < count; i++) {
			accList.add(new Account(Name = 'Test Account ' + i));
		}

		if (doInsert) {
			insert accList;
		}
		return accList;
	}

	public static List<Contact> createContacts(List<Account> accList, Integer contactsPerAccount, Boolean doInsert) {
		List<Contact> conList = new List<Contact>();

		for (Account acc : accList) {
			for (Integer i = 0; i < contactsPerAccount; i++) {
				conList.add(new Contact(
					FirstName = 'Test',
					LastName = acc.Name + ' Contact ' + i,
					AccountId = acc.Id
				));
			}
		}

		if (doInsert) {
			insert conList;
		}
		return conList;
	}

	public static List<Opportunity> createOpportunities(Id accountId, Integer count, String stageName, Boolean doInsert) {
		List<Opportunity> oppList = new List<Opportunity>();

		for (Integer i = 0; i < count; i++) {
			oppList.add(new Opportunity(
				Name = 'Test Opportunity ' + i,
				AccountId = accountId,
				StageName = stageName,
				CloseDate = Date.today().addDays(30)
			));
		}

		if (doInsert) {
			insert oppList;
		}
		return oppList;
	}
}
