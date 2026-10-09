public with sharing class TriggerFactory implements TriggerInterface{
    public TriggerFactory() {

    }

    private static TriggerInterface getTriggerHandler(Type cls){
        Object obj = cls.newInstance();
        if(obj instanceof TriggerInterface){
            return (TriggerInterface) obj;
        } else {    
            return null;
        }
    }

    public void createAndExecuteHandler(Type cls){
        TriggerInterface handler = getTriggerHandler(cls);
        if(handler!=null){
            if(Trigger.isBefore){
                executeBeforeTrigger(handler);
            }
            
            if(Trigger.isAfter){
                executeAfterTrigger(handler);
            }

        } 

    }

    public void executeBeforeTrigger(TriggerInterface handler){
        if(Trigger.isInsert){
            handler.beforeInsert(Trigger.new);
        }

        if(trigger.isUpdate){
            handler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }

    }

    public void executeAfterTrigger(TriggerInterface handler){}

}