trigger LeadTrigger on Lead (before insert, before update, after insert, after update) {
    
    ByPassSetting__c byPassSetting= ByPassSetting__c.getInstance(UserInfo.getUserId());    
    
    if(byPassSetting.ByPassSetting__c == false && byPassSetting.Obj_name__c == 'Opportunity' ){
    
    TRIGGERfACTORY.createAndExecuteHandler(oPPORTUNITYTriggerHandler.class)
}