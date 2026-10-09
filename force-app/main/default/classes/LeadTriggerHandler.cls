public with sharing class LeadTriggerHandler implements TriggerInterface {
    public LeadTriggerHandler() {

    }

    public void beforeInsert(List<SObject> newList) {
        System.debug('before insert');
        List<Lead> leadList = (List<Lead>) newList;
        Set<String>  emailList = new Set<String>();
        Set<String>  phoneList = new Set<String>();
        for(Lead ld : leadList){
            if(String.isNotBlank(ld.email)){
                emailList.add(ld.email);
            }
            if(String.isNotBlank(ld.phone)){
                phoneList.add(ld.phone);
            }

        }
        Map<String, Lead> emailToLeadMap = new Map<String, Lead>();
        Map<String, Lead> phoneToLeadMap = new Map<String, Lead>();

        for(Lead existingL:[Select Id,email,phone,company from Lead where 
            email in::emailList or phone in :phoneList and isConverted = false]){ 
            System.debug('existing lead with same email or phone: ' + existingL);
            if(String.isNotBlank(existingL.email)){
                emailToLeadMap.put(existingL.email, existingL);
            }
            if(String.isNotBlank(existingL.phone)){
                phoneToLeadMap.put(existingL.phone, existingL);

            }
        }

        for(Lead ld:leadList){
            if(oldMap==null || (oldmap!=null && ld.email!=oldmap.get(ld.id).email)){
                if(String.isNotBlank(ld.email) && emailToLeadMap.containsKey(ld.email)){
                    ld.addError('A lead with '+ld.name+' has same email already exists. Please use a different email.');
                }}

            if(oldMap==null || (oldmap!=null && ld.phone!=oldmap.get(ld.id).phone)){
                if(String.isNotBlank(ld.phone) && phoneToLeadMap.containsKey(ld.phone)){
                    ld.addError('A lead with '+ld.name+' has same phone already exists. Please use a different phone.');
                }}  
        }

    }




}