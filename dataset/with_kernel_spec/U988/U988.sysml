package ATMSystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    item def BankCard {
        attribute cardNumber : String;
        attribute cardType : String;
    }

    item def PIN {
        attribute value : String;
    }

    item def KeyPress {
        attribute key : String;
    }

    item def DisplayMessage {
        attribute text : String;
    }

    attribute def Amount {
        attribute value : Real;
        attribute currency : String;
    }

    item def TransactionRequest {
        attribute transactionType : String;
        attribute amount : Amount;
        attribute targetAccount : String;
    }

    item def TransactionResponse {
        attribute approved : Boolean;
        attribute newBalance : Amount;
        attribute responseText : String;
    }

    item def Cash {
        attribute denomination : Integer;
    }

    item def Receipt {
        attribute transactionType : String;
        attribute amount : Amount;
        attribute accountBalance : Amount;
    }

    item def EncryptedData {
        attribute ciphertext : String;
    }

    item def TamperAlert;

    attribute def CardInserted;
    attribute def CardRead;
    attribute def PinEntered;
    attribute def AuthSuccess;
    attribute def AuthFailure;
    attribute def TransactionSelected;
    attribute def DispenseComplete;
    attribute def ReceiptPrinted;

    port def CardDataPort {
        out item cardData : BankCard;
    }

    port def KeypadPort {
        out item keyPress : KeyPress;
    }

    port def DisplayPort {
        in item displayMsg : DisplayMessage;
    }

    port def SecurityPort {
        in attribute plainText : String;
        out item encryptedData : EncryptedData;
        out item tamperAlert : TamperAlert;
    }

    port def NetworkPort {
        out item request : TransactionRequest;
        in item response : TransactionResponse;
    }

    port def DispenserPort {
        in attribute amount : Amount;
        out item cash : Cash;
    }

    port def PrinterPort {
        in item receiptData : Receipt;
    }

    action def ReadCard {
        out item card : BankCard;
    }

    action def PromptForPin {
        out item pin : PIN;
    }

    action def EncryptPin {
        in item pin : PIN;
        out item encrypted : EncryptedData;
    }

    action def AuthenticateUser {
        in item card : BankCard;
        in item encryptedPin : EncryptedData;
        out attribute success : Boolean;
    }

    action def ProcessTransaction {
        in item request : TransactionRequest;
        out item response : TransactionResponse;
    }

    action def DispenseCash {
        in attribute amount : Amount;
        out item cash : Cash;
    }

    action def PrintReceipt {
        in item receipt : Receipt;
    }

    action def EndSession;

    action def RecordPinAttempt;

    action def MonitorTamper {
        out item alert : TamperAlert;
    }

    action def EstablishConnection {
        out attribute connected : Boolean;
    }

    part def CardReader {
        port cardSlot : CardDataPort;
        perform action readCard : ReadCard;
    }

    part def Keypad {
        port keys : KeypadPort;
        perform action promptForPin : PromptForPin;
    }

    part def Display {
        port screen : DisplayPort;
    }

    part def SecurityModule {
        port crypto : SecurityPort;
        perform action encryptData : EncryptPin;
        perform action monitorTamper : MonitorTamper;
    }

    part def NetworkInterface {
        port controllerLink : ~NetworkPort;
        port bankLink : NetworkPort;
        perform action establishConnection : EstablishConnection;
    }

    part def CashDispenser {
        port dispenser : DispenserPort;
        attribute inventory20 : Integer;
        attribute inventory50 : Integer;
        attribute inventory100 : Integer;
        perform action dispenseCash : DispenseCash;
    }

    part def ReceiptPrinter {
        port printer : PrinterPort;
        perform action printReceipt : PrintReceipt;
    }

    part def CentralController {
        port cardDataIn : ~CardDataPort;
        port keypadDataIn : ~KeypadPort;
        port displayDataOut : ~DisplayPort;
        port securityLink : ~SecurityPort;
        port networkLink : NetworkPort;
        port dispenserLink : ~DispenserPort;
        port printerLink : ~PrinterPort;

        exhibit state atmSession : ATMSession;
    }

    state def ATMSession {
        attribute pinAttempts : Integer = 0;

        entry; then idle;

        state idle;

        transition idle_to_readingCard
            first idle
            accept CardInserted
            then readingCard;

        state readingCard {
            do action readCard : ReadCard;
        }

        transition readingCard_to_awaitingPin
            first readingCard
            accept CardRead
            then awaitingPin;

        state awaitingPin {
            do action promptForPin : PromptForPin;
        }

        transition awaitingPin_to_authenticating
            first awaitingPin
            accept PinEntered
            do action encryptPin : EncryptPin
            then authenticating;

        transition awaitingPin_timeout
            first awaitingPin
            accept after 60[s]
            then idle;

        state authenticating {
            do action authenticateUser : AuthenticateUser;
        }

        transition authenticating_to_processing
            first authenticating
            accept AuthSuccess
            then processingTransaction;

        transition authenticating_to_awaitingPin
            first authenticating
            accept AuthFailure
            if pinAttempts < 3
            do action recordPinAttempt : RecordPinAttempt
            then awaitingPin;

        transition authenticating_to_idle
            first authenticating
            accept AuthFailure
            if pinAttempts >= 3
            then idle;

        transition authenticating_timeout
            first authenticating
            accept after 60[s]
            then idle;

        state processingTransaction {
            do action processTransaction : ProcessTransaction;
        }

        transition processing_to_dispensing
            first processingTransaction
            accept TransactionSelected
            then dispensingCash;

        transition processing_timeout
            first processingTransaction
            accept after 60[s]
            then idle;

        state dispensingCash {
            do action dispenseCash : DispenseCash;
        }

        transition dispensing_to_printing
            first dispensingCash
            accept DispenseComplete
            then printingReceipt;

        state printingReceipt {
            do action printReceipt : PrintReceipt;
        }

        transition printing_to_idle
            first printingReceipt
            accept ReceiptPrinted
            then idle;
    }

    requirement def SecureAccess {
        doc /* The ATM shall provide customers with secure, 24/7 access to automated banking services. */
    }

    requirement def PinAttemptLimit {
        doc /* The system shall limit PIN entry to three attempts before ending the session. */
        attribute maxAttempts : Integer = 3;
    }

    requirement def SessionTimeout {
        doc /* The system shall automatically end a session after 60 seconds of inactivity. */
        attribute timeout : Real = 60;
    }

    requirement def CashInventoryCheck {
        doc /* The cash dispenser shall only dispense cash after bank approval and sufficient funds. */
    }

    requirement def SecureConnection {
        doc /* The ATM shall establish a secure, encrypted connection to the central banking system. */
    }

    requirement secureAccess : SecureAccess;
    requirement pinAttemptLimit : PinAttemptLimit;
    requirement sessionTimeout : SessionTimeout;
    requirement cashInventoryCheck : CashInventoryCheck;
    requirement secureConnection : SecureConnection;

    part def ATM {
        port bankPort : ~NetworkPort;

        part cardReader : CardReader;
        part keypad : Keypad;
        part display : Display;
        part securityModule : SecurityModule;
        part networkInterface : NetworkInterface;
        part cashDispenser : CashDispenser;
        part receiptPrinter : ReceiptPrinter;
        part controller : CentralController;

        connect cardReader.cardSlot to controller.cardDataIn;
        connect keypad.keys to controller.keypadDataIn;
        connect controller.displayDataOut to display.screen;
        connect controller.securityLink to securityModule.crypto;
        connect controller.networkLink to networkInterface.controllerLink;
        connect controller.dispenserLink to cashDispenser.dispenser;
        connect controller.printerLink to receiptPrinter.printer;
        connect networkInterface.bankLink to bankPort;
    }

    part atm : ATM;
}
