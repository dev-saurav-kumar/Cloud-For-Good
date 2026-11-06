/**
 * Description        : When an Opportunity stage is Closed Won, adds one Opportunity Contact Role for each Contact of the Account associated with the Opportunity.
 * Author             : Saurav Kumar
 * Created Date       : 05-Nov-2026
 * Last Modified Date : 05-Nov-2026
 */
public without sharing class OpportunityTriggerHelper {

	// Recursion guard - Opportunities already processed in this transaction
	private static Set<Id> processedOppIds = new Set<Id>();

	public static void addContactRoles(List<Opportunity> newOppList, Map<Id, Opportunity> oldOppMap) {

		// Opportunity Id to Account Id, only for Opportunities that have just moved to Closed Won
		Map<Id, Id> oppIdToAccIdMap = new Map<Id, Id>();

		//Logic for opportunity insertion
		if (oldOppMap == null) {
			for (Opportunity opp : newOppList) {
				if (opp.StageName == System.Label.OPP_Closed_Won_Stage && opp.AccountId != null && !processedOppIds.contains(opp.Id)) {
					oppIdToAccIdMap.put(opp.Id, opp.AccountId);
				}
			}
		}
		else {
			//Logic for opportunity updation
			for (Opportunity opp : newOppList) {
				Opportunity oldOpp = oldOppMap.get(opp.Id);
				if (oldOpp.StageName != System.Label.OPP_Closed_Won_Stage && opp.StageName == System.Label.OPP_Closed_Won_Stage && opp.AccountId != null && !processedOppIds.contains(opp.Id)) {
					oppIdToAccIdMap.put(opp.Id, opp.AccountId);
				}
			}
		}

		// Nothing has moved to Closed Won
		if (oppIdToAccIdMap.isEmpty()) {
			return;
		}

		// Mark as processed so the logic does not run again in the same transaction
		processedOppIds.addAll(oppIdToAccIdMap.keySet());

		try {
			// Account Id to its Contact Ids
			Map<Id, List<Id>> accIdToContactIdsMap = new Map<Id, List<Id>>();

			for (Contact con : [SELECT Id, AccountId FROM Contact WHERE AccountId IN :oppIdToAccIdMap.values()]) {
				if (!accIdToContactIdsMap.containsKey(con.AccountId)) {
					accIdToContactIdsMap.put(con.AccountId, new List<Id>());
				}
				accIdToContactIdsMap.get(con.AccountId).add(con.Id);
			}

			// Existing Opportunity Contact Roles on these Opportunities, stored as "OpportunityId-ContactId" to prevent duplicates
			Set<String> existingOppConRoleKeys = new Set<String>();

			for (OpportunityContactRole ocr : [SELECT OpportunityId, ContactId FROM OpportunityContactRole WHERE OpportunityId IN :oppIdToAccIdMap.keySet()]) {
				existingOppConRoleKeys.add(ocr.OpportunityId + '-' + ocr.ContactId);
			}

			List<OpportunityContactRole> oppConRoleToInsert = new List<OpportunityContactRole>();

			for (Id oppId : oppIdToAccIdMap.keySet()) {
				// Only the Contacts of this Opportunity's own Account
				List<Id> contactIds = accIdToContactIdsMap.get(oppIdToAccIdMap.get(oppId));

				if (contactIds == null) {
					continue;
				}

				for (Id conId : contactIds) {
					String key = oppId + '-' + conId;

					// Skip if the Opportunity Contact Role already exists
					if (!existingOppConRoleKeys.contains(key)) {
						oppConRoleToInsert.add(new OpportunityContactRole(
							OpportunityId = oppId,
							ContactId = conId,
							IsPrimary = true,
							Role = System.Label.OCR_Default_Role
						));
						existingOppConRoleKeys.add(key);
					}
				}
			}

			if (!oppConRoleToInsert.isEmpty()) {
				Database.SaveResult[] results = Database.insert(oppConRoleToInsert, false);

				for (Database.SaveResult result : results) {
					if (!result.isSuccess()) {
						for (Database.Error err : result.getErrors()) {
							System.debug('Opportunity Contact Role insertion failed => ' + err.getStatusCode() + ' - ' + err.getMessage());
						}
					}
				}
			}
		}
		catch (Exception e) {
			System.debug('Error in OpportunityTriggerHelper.addContactRoles: ' + e.getMessage() + ' at line ' + e.getLineNumber());
		}
	}
}