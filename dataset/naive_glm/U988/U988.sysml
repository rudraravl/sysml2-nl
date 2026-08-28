package ATM_System {
    import ISQ::*;
    
    package Definitions {
        value type USD :> Real {
            unit "USD";
        }
        
        item def BankCard {
            attribute cardType : String;
            attribute cardNumber : String;
        }
        
        item def TransactionRequest {
            attribute type : String;
            attribute amount : USD;
            attribute accountNumber : String;
        }
        
        item def TransactionResponse {
            attribute approved : Boolean;
            attribute newBalance : USD;
        }
        
        item def Receipt {
            attribute transactionType : String;
            attribute amount : USD;
            attribute accountBalance : USD;
        }
        
        item def Cash {
            attribute denomination : USD;
        }
        
        port def CardPort {
            out item card : BankCard;
        }
        
        port def KeypadPort {
            out item input : String;
        }
        
        port def DisplayPort {
            in item displayData : String;
        }
        
        port def DispenserPort {
            in item dispenseRequest : TransactionRequest;
            out item dispensedCash : Cash;
        }
        
        port def PrinterPort {
            in item receiptData : Receipt;
        }
        
        port def NetworkPort {
            in item request : TransactionRequest;
            out item response : TransactionResponse;
        }
        
        port def SecurityPort {
            in item sensitiveData : String;
            out item encryptedData : String;
            out item tamperAlert : Boolean;
        }
    }
    
    package Requirements {
        requirement def ATM_Requirement {
            doc "The ATM shall provide secure, 24/7 access to automated banking services."
        }
        
        requirement def CardReader_Requirement {
            doc "The card reader shall handle both magnetic stripe and chip cards."
        }
        
        requirement def PIN_Limit_Requirement {
            doc "The system shall limit PIN entry to three attempts."
        }
        
        requirement def Inactivity_Requirement {
            doc "The system shall automatically end a session after 60 seconds of inactivity."
        }
        
        requirement def Dispenser_Requirement {
            doc "The cash dispenser shall only dispense cash after receiving approval and ensuring sufficient funds."
        }
    }
    
    package Components {
        part def CardReader {
            port cardOut : CardPort;
            attribute supportsMagneticStripe : Boolean = true;
            attribute supportsChip : Boolean = true;
        }
        
        part def Keypad {
            port keyOut : KeypadPort;
        }
        
        part def Display {
            port displayIn : DisplayPort;
        }
        
        part def CashDispenser {
            port controlPort : DispenserPort;
            attribute inventory20 : Integer = 1000;
            attribute inventory50 : Integer = 500;
            attribute inventory100 : Integer = 200;
        }
        
        part def ReceiptPrinter {
            port printerIn : PrinterPort;
        }
        
        part def SecurityModule {
            port secPort : SecurityPort;
            attribute tamperDetected : Boolean = false;
        }
        
        part def NetworkInterface {
            port netPort : NetworkPort;
            attribute connectionSecure : Boolean = true;
        }
        
        part def CentralController {
            port cardIn : CardPort;
            port keyIn : KeypadPort;
            port displayOut : DisplayPort;
            port dispenserPort : DispenserPort;
            port printerOut : PrinterPort;
            port secPort : SecurityPort;
            port netPort : NetworkPort;
            
            attribute pinAttempts : Integer = 0;
            attribute maxPinAttempts : Integer = 3;
            attribute inactivityTimer : Time = 60 [s];
            
            state machine SessionBehavior {
                state idle;
                state readingCard;
                state awaitingPIN;
                state authenticating;
                state processingTransaction;
                state dispensingCash;
                state printingReceipt;
                state sessionEnded;
                
                transition idle_to_readingCard
                    first idle if cardIn.card.cardNumber != null then readingCard;
                    
                transition readingCard_to_awaitingPIN
                    first readingCard then awaitingPIN;
                    
                transition awaitingPIN_to_authenticating
                    first awaitingPIN if keyIn.input != null then authenticating;
                    
                transition authenticating_to_processing
                    first authenticating if netPort.response.approved then processingTransaction;
                    
                transition authenticating_to_awaitingPIN_retry
                    first authenticating if !netPort.response.approved and pinAttempts < maxPinAttempts then awaitingPIN;
                    
                transition authenticating_to_sessionEnded_fail
                    first authenticating if !netPort.response.approved and pinAttempts >= maxPinAttempts then sessionEnded;
                    
                transition processing_to_dispensing
                    first processingTransaction if dispenserPort.dispensedCash != null then dispensingCash;
                    
                transition dispensing_to_printing
                    first dispensingCash then printingReceipt;
                    
                transition printing_to_idle
                    first printingReceipt then idle;
                    
                transition any_to_sessionEnded_timeout
                    first idle, readingCard, awaitingPIN, authenticating, processingTransaction, dispensingCash, printingReceipt if inactivityTimer == 0 [s] then sessionEnded;
            }
        }
    }
    
    package ATM {
        import Definitions::*;
        import Components::*;
        import Requirements::*;
        
        part AutomatedTellerMachine {
            satisfy ATM_Requirement;
            
            part cardReader : CardReader {
                satisfy CardReader_Requirement;
            }
            part keypad : Keypad;
            part display : Display;
            part cashDispenser : CashDispenser {
                satisfy Dispenser_Requirement;
            }
            part receiptPrinter : ReceiptPrinter;
            part securityModule : SecurityModule;
            part networkInterface : NetworkInterface;
            part controller : CentralController {
                satisfy PIN_Limit_Requirement;
                satisfy Inactivity_Requirement;
            }
            
            connection cardConnection connect cardReader.cardOut to controller.cardIn;
            connection keypadConnection connect keypad.keyOut to controller.keyIn;
            connection displayConnection connect controller.displayOut to display.displayIn;
            connection dispenserConnection connect controller.dispenserPort to cashDispenser.controlPort;
            connection printerConnection connect controller.printerOut to receiptPrinter.printerIn;
            connection securityConnection connect controller.secPort to securityModule.secPort;
            connection networkConnection connect controller.netPort to networkInterface.netPort;
        }
    }
}
