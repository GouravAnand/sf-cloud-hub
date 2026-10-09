({
    /**
     * Updates the parent message and sends it to child component
     */
    updateParentMessage : function(component, event, helper) {
        var messageInput = component.find('parentMessageInput');
        var message = messageInput.get('v.value');
        
        if(message && message.trim() !== '') {
            component.set('v.parentMessage', message);
            console.log('Parent message updated: ' + message);
        } else {
            alert('Please enter a message');
        }
    },
    
    /**
     * Handles events fired from child component
     * Receives child message and counter value
     */
    handleChildEvent : function(component, event, helper) {
        var eventParams = event.getParam('arguments');
        
        if(eventParams) {
            var childMessage = eventParams.message;
            var childCounter = eventParams.counter;
            
            // Update parent attributes with child data
            component.set('v.childMessage', childMessage);
            component.set('v.childCount', childCounter);
            
            console.log('Parent received from child - Message: ' + childMessage + ', Counter: ' + childCounter);
        }
    }
})