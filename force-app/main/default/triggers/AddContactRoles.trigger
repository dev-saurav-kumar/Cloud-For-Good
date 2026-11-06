trigger AddContactRoles on Opportunity (after insert, after update) {
	if (Trigger.isAfter) {
		if (Trigger.isInsert) {
			OpportunityTriggerHelper.addContactRoles(Trigger.new, null);
		}
		if (Trigger.isUpdate) {
			OpportunityTriggerHelper.addContactRoles(Trigger.new, Trigger.oldMap);
		}
	}
}
