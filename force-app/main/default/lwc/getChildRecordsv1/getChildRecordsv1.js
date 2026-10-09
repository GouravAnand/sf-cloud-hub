import { LightningElement,api,wire } from 'lwc';
import getChildRecords from '@salesforce/apex/ChildRecordController.getChildRecords';
export default class GetChildRecordsv1 extends LightningElement {
    @api recordId;
    @wire(getChildRecords, { parentId: '$recordId' })
    childRecords;   

    
}