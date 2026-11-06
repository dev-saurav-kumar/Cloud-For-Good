/**
 * Description        : Test class for OpportunityTrigger and OpportunityTriggerHelper.
 * Author             : Saurav Kumar
 * Created Date       : 05-Nov-2026
 * Last Modified Date : 06-Nov-2026
 */
@isTest
private class OpportunityTriggerHelperTest {
	private static final String OPEN_STAGE = 'Prospecting';
	private static final Integer CONTACTS_PER_ACCOUNT = 3;

	@testSetup
	static void setupData() {
		List<Account> accList = TestDataFactory.createAccounts(3, true);

		TestDataFactory.createContacts(new List<Account>{ accList[0], accList[1] }, CONTACTS_PER_ACCOUNT, true);
	}

	private static Account getAccount(String accName) {
		return [SELECT Id FROM Account WHERE Name = :accName LIMIT 1];
	}

	private static List<OpportunityContactRole> getOppConRoles(Id oppId) {
		return [SELECT Id, ContactId, Role FROM OpportunityContactRole WHERE OpportunityId = :oppId];
	}

	@isTest
	static void createClosedWonOpp() {
		Account acc = getAccount('Test Account 0');

		Test.startTest();
		Opportunity opp = TestDataFactory.createOpportunities(acc.Id, 1, System.Label.OPP_Closed_Won_Stage, true)[0];
		Test.stopTest();

		List<OpportunityContactRole> oppConRoles = getOppConRoles(opp.Id);
		Assert.areEqual(CONTACTS_PER_ACCOUNT, oppConRoles.size(), 'Each Contact should get an Opportunity Contact Role');
		Assert.areEqual(System.Label.OCR_Default_Role, oppConRoles[0].Role, 'Role field of Opportunity Contact Role should come from the custom label');
	}

	@isTest
	static void moveToClosedWon() {
		Account acc = getAccount('Test Account 0');
		Opportunity opp = TestDataFactory.createOpportunities(acc.Id, 1, OPEN_STAGE, true)[0];
		Assert.areEqual(0, getOppConRoles(opp.Id).size(), 'Open Opportunity should not have any Opportunity Contact Role');

		Test.startTest();
		opp.StageName = System.Label.OPP_Closed_Won_Stage;
		update opp;
		Test.stopTest();

		Assert.areEqual(CONTACTS_PER_ACCOUNT, getOppConRoles(opp.Id).size(), 'Each Contact should get an Opportunity Contact Role');
	}

	@isTest
	static void openOppNoOppConRole() {
		Account acc = getAccount('Test Account 0');
		Opportunity opp = TestDataFactory.createOpportunities(acc.Id, 1, OPEN_STAGE, true)[0];

		Test.startTest();
		opp.Name = 'Renamed Opp';
		update opp;
		Test.stopTest();

		Assert.areEqual(0, getOppConRoles(opp.Id).size(), 'No Opportunity Contact Role should be created');
	}

	@isTest
	static void accountWithoutContacts() {
		Account acc = getAccount('Test Account 2');

		Test.startTest();
		Opportunity opp = TestDataFactory.createOpportunities(acc.Id, 1, System.Label.OPP_Closed_Won_Stage, true)[0];
		Test.stopTest();

		Assert.areEqual(0, getOppConRoles(opp.Id).size(), 'No Opportunity Contact Role should be created');
	}

	@isTest
	static void noDuplicateOppConRole() {
		Account acc = getAccount('Test Account 0');
		Opportunity opp = TestDataFactory.createOpportunities(acc.Id, 1, OPEN_STAGE, true)[0];
		Contact con = [SELECT Id FROM Contact WHERE AccountId = :acc.Id LIMIT 1];
		insert new OpportunityContactRole(OpportunityId = opp.Id, ContactId = con.Id, Role = 'Decision Maker');

		Test.startTest();
		opp.StageName = System.Label.OPP_Closed_Won_Stage;
		update opp;
		Test.stopTest();

		List<OpportunityContactRole> oppConRoles = getOppConRoles(opp.Id);
		Assert.areEqual(CONTACTS_PER_ACCOUNT, oppConRoles.size(), 'Existing Contact should not get a second Opportunity Contact Role');

		Integer conOppConRoleCount = 0;
		for (OpportunityContactRole ocr : oppConRoles) {
			if (ocr.ContactId == con.Id) {
				conOppConRoleCount++;
			}
		}
		Assert.areEqual(1, conOppConRoleCount, 'Contact should have only one Opportunity Contact Role');
	}

	@isTest
	static void oppConRoleFromOwnAccount() {
		Account acc0 = getAccount('Test Account 0');
		Account acc1 = getAccount('Test Account 1');
		List<Opportunity> oppList = new List<Opportunity>();
		oppList.addAll(TestDataFactory.createOpportunities(acc0.Id, 1, System.Label.OPP_Closed_Won_Stage, false));
		oppList.addAll(TestDataFactory.createOpportunities(acc1.Id, 1, System.Label.OPP_Closed_Won_Stage, false));

		Test.startTest();
		insert oppList;
		Test.stopTest();

		Set<Id> acc0ContactIds = new Map<Id, Contact>([SELECT Id FROM Contact WHERE AccountId = :acc0.Id]).keySet();
		for (OpportunityContactRole ocr : getOppConRoles(oppList[0].Id)) {
			Assert.isTrue(acc0ContactIds.contains(ocr.ContactId), 'Opportunity Contact Role should use a Contact from the same Account');
		}
		Assert.areEqual(CONTACTS_PER_ACCOUNT, getOppConRoles(oppList[1].Id).size(), 'Second Opportunity should get its own Opportunity Contact Roles');
	}

	@isTest
	static void bulkClosedWon() {
		Account acc = getAccount('Test Account 1');
		List<Opportunity> oppList = TestDataFactory.createOpportunities(acc.Id, 50, OPEN_STAGE, true);

		Test.startTest();
		for (Opportunity opp : oppList) {
			opp.StageName = System.Label.OPP_Closed_Won_Stage;
		}
		update oppList;
		Test.stopTest();

		Integer total = [SELECT COUNT() FROM OpportunityContactRole WHERE OpportunityId IN :oppList];
		Assert.areEqual(50 * CONTACTS_PER_ACCOUNT, total, 'All Opportunities should get Opportunity Contact Roles');
	}

	@isTest
	static void runOnlyOnce() {
		Account acc = getAccount('Test Account 0');

		Test.startTest();
		Opportunity opp = TestDataFactory.createOpportunities(acc.Id, 1, System.Label.OPP_Closed_Won_Stage, true)[0];
		delete [SELECT Id FROM OpportunityContactRole WHERE OpportunityId = :opp.Id];

		opp.StageName = OPEN_STAGE;
		update opp;
		opp.StageName = System.Label.OPP_Closed_Won_Stage;
		update opp;
		Test.stopTest();

		Assert.areEqual(0, getOppConRoles(opp.Id).size(), 'Recursion guard should skip the second run, so no Opportunity Contact Role is created');
	}
}
