trigger ProjectTrigger on Project__c (after insert, after update, after delete, after undelete) {
    ProjectTriggerHandler handler = new ProjectTriggerHandler();

    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            handler.onAfterInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            handler.onAfterUpdate(Trigger.new, Trigger.oldMap);
        }
        if (Trigger.isDelete) {
            handler.onAfterDelete(Trigger.old);
        }
        if (Trigger.isUndelete) {
            handler.onAfterUndelete(Trigger.new);
        }
    }
}