package CBusBuildingAutomation {
    import ScalarValues::*;
    import ISQ::*;
    
    // Value Types
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Power :> Real { unit 'W'; }
    value type Temperature :> Real { unit 'degC'; }
    value type Percent :> Real { unit '%'; }
    value type Duration :> Real { unit 's'; }
    
    // Enumerations
    enum OccupancyState { occupied, unoccupied; }
    enum ArmedState { disarmed, armed_away, armed_stay; }
    enum MessagePriority { low, medium, high, critical; }
    
    // Item Types
    item PowerFlow {
        attr voltage : Voltage;
        attr current : Current;
    }
    
    item BusMessage {
        attr priority : MessagePriority;
        attr source : String;
        attr destination : String;
        attr payload : Anything;
    }
    
    item LightingCommand {
        attr brightness : Percent;
        attr rampRate : Duration;
    }
    
    item ClimateCommand {
        attr targetTemp : Temperature;
        attr fanSpeed : Percent;
    }
    
    item SecurityCommand {
        attr armedState : ArmedState;
        attr triggerAlarm : Boolean;
    }
    
    item OccupancyReport {
        attr state : OccupancyState;
    }
    
    // Ports
    port def BusPort {
        in PowerFlow;
        out PowerFlow;
        in BusMessage;
        out BusMessage;
    }
    
    // Requirements
    requirement def DecentralizedControl {
        doc "The system shall operate as a peer-to-peer network with no single central computer managing operations."
    }
    
    requirement def SharedBusPowerData {
        doc "The shared two-wire electrical bus shall provide both low-voltage power and data communication to all connected devices."
    }
    
    requirement def PriorityBasedCommunication {
        doc "Communication shall be managed through a priority-based system that prevents message collisions and ensures critical alerts are transmitted with precedence over routine updates."
    }
    
    requirement def DeviceAutonomy {
        doc "Each device shall operate independently through states: initializing, idling, listening, processing, and transmitting."
    }
    
    // State Machine
    state def DeviceBehavior {
        entry; then Initializing;
        
        state Initializing;
        transition init_to_idle 
            first Initializing 
            then Idle;
            
        state Idle;
        transition idle_to_listening 
            first Idle 
            then Listening 
            accept BusMessage;
            
        state Listening;
        transition listening_to_processing 
            first Listening 
            then Processing;
            
        state Processing;
        transition processing_to_transmitting 
            first Processing 
            then Transmitting 
            when needToSend;
            
        transition processing_to_idle 
            first Processing 
            then Idle 
            when !needToSend;
            
        state Transmitting;
        transition transmitting_to_idle 
            first Transmitting 
            then Idle;
    }
    
    // Parts
    part def PowerSupplyUnit {
        port busPort : BusPort;
        attribute outputPower : Power = 30.0;
    }
    
    part def ElectricalBus {
        port busPort : BusPort;
        attribute wireCount : Integer = 2;
    }
    
    part def LightingController {
        port busPort : BusPort;
        attribute currentBrightness : Percent = 0.0;
        attribute currentRampRate : Duration = 0.0;
        attribute needToSend : Boolean = false;
        
        exhibit state behavior : DeviceBehavior;
        
        action processLightingCommand {
            in cmd : LightingCommand;
        }
    }
    
    part def ClimateController {
        port busPort : BusPort;
        attribute currentTemp : Temperature = 22.0;
        attribute targetTemp : Temperature = 22.0;
        attribute fanSpeed : Percent = 50.0;
        attribute needToSend : Boolean = false;
        
        exhibit state behavior : DeviceBehavior;
        
        action processClimateCommand {
            in cmd : ClimateCommand;
        }
    }
    
    part def SecurityController {
        port busPort : BusPort;
        attribute armedState : ArmedState = ArmedState::disarmed;
        attribute alarmActive : Boolean = false;
        attribute needToSend : Boolean = false;
        
        exhibit state behavior : DeviceBehavior;
        
        action processSecurityCommand {
            in cmd : SecurityCommand;
        }
    }
    
    part def OccupancySensor {
        port busPort : BusPort;
        attribute occupancyState : OccupancyState = OccupancyState::unoccupied;
        attribute needToSend : Boolean = false;
        
        exhibit state behavior : DeviceBehavior;
        
        action detectMotion {
            // detect person entering
        }
    }
    
    part def CBusNetwork {
        satisfy DecentralizedControl;
        satisfy SharedBusPowerData;
        satisfy PriorityBasedCommunication;
        satisfy DeviceAutonomy;
        
        part psu : PowerSupplyUnit;
        part bus : ElectricalBus;
        part lightingCtrl : LightingController;
        part climateCtrl : ClimateController;
        part securityCtrl : SecurityController;
        part occupancySens : OccupancySensor;
        
        connection busPower connects psu.busPort to bus.busPort;
        connection lightingConn connects bus.busPort to lightingCtrl.busPort;
        connection climateConn connects bus.busPort to climateCtrl.busPort;
        connection securityConn connects bus.busPort to securityCtrl.busPort;
        connection occupancyConn connects bus.busPort to occupancySens.busPort;
    }
}
