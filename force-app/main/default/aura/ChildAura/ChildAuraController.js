({
    /**
     * Sends child message to parent component
     */
    sendMessageToParent : function(component, event, helper) {
        var messageInput = component.find('childMessageInput');
        var message = messageInput.get('v.value');
        var counter = component.get('v.counter');
        
        if(message && message.trim() !== '') {
            component.set('v.childMessage', message);
            
            // Fire event to parent with message and counter
            var childEvent = component.getEvent('childEvent');
            childEvent.setParams({
                'message': message,
                'counter': counter
            });
            childEvent.fire();
            
            console.log('Child sent message to parent: ' + message);
        } else {
            alert('Please enter a message');
        }
    },
    
    /**
     * Increments the counter value
     */
    incrementCounter : function(component, event, helper) {
        var currentCounter = component.get('v.counter');
        component.set('v.counter', currentCounter + 1);
        console.log('Counter incremented to: ' + (currentCounter + 1));
    },
    
    /**
     * Decrements the counter value
     */
    decrementCounter : function(component, event, helper) {
        var currentCounter = component.get('v.counter');
        var newCounter = currentCounter > 0 ? currentCounter - 1 : 0;
        component.set('v.counter', newCounter);
        console.log('Counter decremented to: ' + newCounter);
    },
    
    /**
     * Resets the counter to zero
     */
    resetCounter : function(component, event, helper) {
        component.set('v.counter', 0);
        console.log('Counter reset to 0');
    },
    
    /**
     * Sends current counter value to parent component
     */
    sendCounterToParent : function(component, event, helper) {
        var message = component.get('v.childMessage');
        var counter = component.get('v.counter');
        
        // Fire event to parent with current message and counter
        var childEvent = component.getEvent('childEvent');
        childEvent.setParams({
            'message': message,
            'counter': counter
        });
        childEvent.fire();
        
        console.log('Child sent counter to parent: ' + counter);
    }
})