package MobileInternetDevice {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types =====
    
    value type ChargeLevel :> Real {
        :>> unit = "%";
    }
    
    value type Voltage :> Real {
        :>> unit = "V";
    }
    
    value type Current :> Real {
        :>> unit = "A";
    }
    
    value type Power :> Real {
        :>> unit = "W";
    }
    
    value type DataRate :> Real {
        :>> unit = "Mbps";
    }
    
    value type BrightnessLevel :> Real {
        :>> unit = "cd";
    }
    
    value type Temperature :> Real {
        :>> unit = "K";
    }
    
    // ===== Item Definitions =====
    
    item def TouchEvent {
        attribute x : Real;
        attribute y : Real;
        attribute gesture : String;
        attribute timestamp : Real;
    }
    
    item def DisplayFrame {
        attribute width : Integer;
        attribute height : Integer;
        attribute pixelData : String;
    }
    
    item def NetworkRequest {
        attribute url : String;
        attribute method : String;
        attribute payload : String;
    }
    
    item def NetworkResponse {
        attribute statusCode : Integer;
        attribute contentType : String;
        attribute body : String;
    }
    
    item def RenderedContent {
        attribute frame : DisplayFrame;
        attribute brightness : BrightnessLevel;
    }
    
    item def PowerSupply {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    
    item def BatteryStatus {
        attribute charge : ChargeLevel;
        attribute health : Real;
        attribute temperature : Temperature;
    }
    
    item def DataPacket {
        attribute sequence : Integer;
        attribute payload : String;
    }
    
    // ===== Port Definitions =====
    
    port def TouchInputPort {
        out item touchEvents : TouchEvent;
    }
    
    port def DisplayOutputPort {
        out item frames : DisplayFrame;
    }
    
    port def ProcessorRequestPort {
        out item requests : NetworkRequest;
        in item responses : NetworkResponse;
    }
    
    port def ModemResponsePort {
        in item requests : NetworkRequest;
        out item responses : NetworkResponse;
    }
    
    port def ProcessorDisplayPort {
        out item content : RenderedContent;
    }
    
    port def DisplayInputPort {
        in item content : RenderedContent;
    }
    
    port def TouchOutputPort {
        out item events : TouchEvent;
    }
    
    port def ProcessorTouchPort {
        in item events : TouchEvent;
    }
    
    port def PowerOutputPort {
        out item supply : PowerSupply;
    }
    
    port def PowerInputPort {
        in item supply : PowerSupply;
    }
    
    port def BatteryMonitorPort {
        out item status : BatteryStatus;
    }
    
    port def BatteryMonitorInputPort {
        in item status : BatteryStatus;
    }
    
    port def NetworkPort {
        out item outgoingPackets : DataPacket;
        in item incomingPackets : DataPacket;
    }
    
    // ===== Requirements =====
    
    requirement def MobileInternetDeviceRequirements {
        subject device : MobileInternetDevice;
        
        requirement WebBrowsingCapability {
            subject device;
            doc /* The device shall support web browsing through a wireless connection. */
        }
        
        requirement TouchInputResponsiveness {
            subject device;
            doc /* Touch input shall be captured and processed within 50 ms. */
            attribute maxLatency : Real = 50;
        }
        
        requirement WirelessConnectivity {
            subject device;
            doc /* The device shall establish and maintain a wireless network connection. */
            attribute minDataRate : DataRate = 10;
        }
        
        requirement BatteryLife {
            subject device;
            doc /* The device shall operate for at least 8 hours on a full charge under normal usage. */
            attribute minHours : Real = 8;
        }
        
        requirement LowPowerConservation {
            subject device;
            doc /* The system shall enter low-power mode when battery charge falls below 20%. */
            attribute threshold : ChargeLevel = 20;
        }
        
        requirement CriticalPowerShutdown {
            subject device;
            doc /* The system shall enter critical mode and initiate shutdown when battery charge falls below 5%. */
            attribute threshold : ChargeLevel = 5;
        }
        
        satisfy WebBrowsingCapability by device;
        satisfy TouchInputResponsiveness by device.touchController;
        satisfy WirelessConnectivity by device.modem;
        satisfy BatteryLife by device.bms;
        satisfy LowPowerConservation by device.bms;
        satisfy CriticalPowerShutdown by device.bms;
    }
    
    // ===== Part Definitions =====
    
    part def ApplicationProcessor {
        port touchIn : TouchInputPort;
        port modemIf : ProcessorRequestPort;
        port displayOut : ProcessorDisplayPort;
        port powerIn : PowerInputPort;
        port batteryMonitor : BatteryMonitorInputPort;
        
        attribute clockSpeed : DataRate;
        attribute activeProcesses : Integer;
        attribute backgroundProcessLimit : Integer;
        
        state def ProcessorState;
        
        state machine ProcessorStateMachine {
            state Idle;
            state Processing {
                entry action {
                    activeProcesses = activeProcesses + 1;
                }
            }
            state LowPowerMode {
                entry action {
                    backgroundProcessLimit = 2;
                }
            }
            
            transition Idle to Processing
                when touchIn.touchEvents->notEmpty();
            transition Processing to Idle
                when activeProcesses == 0;
            transition Idle to LowPowerMode
                when batteryMonitor.status.charge < 20;
            transition Processing to LowPowerMode
                when batteryMonitor.status.charge < 20;
            transition LowPowerMode to Idle
                when batteryMonitor.status.charge >= 20;
        }
        
        action def ProcessTouchInput {
            in item event : TouchEvent;
            out item request : NetworkRequest;
            
            perform {
                request.url = "https://www.example.com";
                request.method = "GET";
                request.payload = "";
            }
        }
        
        action def ProcessNetworkResponse {
            in item response : NetworkResponse;
            out item content : RenderedContent;
            
            perform {
                content.frame.width = 1080;
                content.frame.height = 1920;
                content.frame.pixelData = response.body;
                content.brightness = 300;
            }
        }
    }
    
    part def TouchInputController {
        port touchOut : TouchOutputPort;
        port powerIn : PowerInputPort;
        
        attribute sampleRate : Real;
        attribute sensitivity : Real;
        
        action def CaptureTouch {
            out item event : TouchEvent;
            
            perform {
                event.x = 0.0;
                event.y = 0.0;
                event.gesture = "tap";
                event.timestamp = 0.0;
            }
        }
    }
    
    part def DisplayController {
        port displayIn : DisplayInputPort;
        port powerIn : PowerInputPort;
        
        attribute resolution : String;
        attribute maxBrightness : BrightnessLevel;
        attribute currentBrightness : BrightnessLevel;
        
        state def DisplayState;
        
        state machine DisplayStateMachine {
            state Off;
            state On;
            state Dimmed {
                entry action {
                    currentBrightness = maxBrightness * 0.3;
                }
            }
            
            transition Off to On
                when displayIn.content->notEmpty();
            transition On to Dimmed
                when currentBrightness < maxBrightness * 0.5;
            transition Dimmed to On
                when currentBrightness >= maxBrightness * 0.5;
            transition On to Off
                when powerIn.supply->isEmpty();
        }
        
        action def RenderContent {
            in item content : RenderedContent;
            
            perform {
                currentBrightness = content.brightness;
            }
        }
    }
    
    part def WirelessModem {
        port modemIn : ModemResponsePort;
        port networkIf : NetworkPort;
        port powerIn : PowerInputPort;
        
        attribute protocol : String;
        attribute signalStrength : Real;
        attribute dataRate : DataRate;
        
        state def ModemState;
        
        state machine ModemStateMachine {
            state Disconnected;
            state Connecting {
                entry action {
                    signalStrength = 0.0;
                }
            }
            state Connected;
            state Transmitting;
            state Receiving;
            
            transition Disconnected to Connecting
                when modemIn.requests->notEmpty();
            transition Connecting to Connected
                when signalStrength > 0.5;
            transition Connected to Transmitting
                when modemIn.requests->notEmpty();
            transition Connected to Receiving
                when networkIf.incomingPackets->notEmpty();
            transition Transmitting to Connected
                when modemIn.requests->isEmpty();
            transition Receiving to Connected
                when networkIf.incomingPackets->isEmpty();
            transition Connected to Disconnected
                when signalStrength == 0.0;
        }
        
        action def SendRequest {
            in item request : NetworkRequest;
            out item packet : DataPacket;
            
            perform {
                packet.sequence = 1;
                packet.payload = request.url;
            }
        }
        
        action def ReceiveResponse {
            in item packet : DataPacket;
            out item response : NetworkResponse;
            
            perform {
                response.statusCode = 200;
                response.contentType = "text/html";
                response.body = packet.payload;
            }
        }
    }
    
    part def RechargeableBattery {
        port powerOut : PowerOutputPort;
        port monitorOut : BatteryMonitorPort;
        
        attribute capacity : Power;
        attribute currentCharge : ChargeLevel;
        attribute nominalVoltage : Voltage;
        attribute health : Real;
        attribute temperature : Temperature;
        
        action def Discharge {
            out item supply : PowerSupply;
            
            perform {
                supply.voltage = nominalVoltage;
                supply.current = 1.0;
            }
        }
        
        action def Charge {
            in item externalPower : PowerSupply;
            
            perform {
                currentCharge = currentCharge + 1.0;
            }
        }
    }
    
    part def BatteryManagementSystem {
        port batteryMonitor : BatteryMonitorPort;
        port powerDistribution : PowerOutputPort;
        port externalPower : PowerInputPort;
        
        attribute chargeThreshold : ChargeLevel;
        attribute criticalThreshold : ChargeLevel;
        attribute isCharging : Boolean;
        
        state def BMSState;
        
        state machine BMSStateMachine {
            state Normal {
                entry action {
                    chargeThreshold = 20;
                    criticalThreshold = 5;
                }
            }
            state LowPower {
                entry action {
                    /* Reduce screen brightness and limit background processes */
                }
            }
            state Critical {
                entry action {
                    /* Initiate shutdown sequence */
                }
            }
            state Charging {
                entry action {
                    isCharging = true;
                }
                exit action {
                    isCharging = false;
                }
            }
            
            transition Normal to LowPower
                when batteryMonitor.status.charge < chargeThreshold;
            transition LowPower to Critical
                when batteryMonitor.status.charge < criticalThreshold;
            transition Normal to Charging
                when externalPower.supply->notEmpty();
            transition LowPower to Charging
                when externalPower.supply->notEmpty();
            transition Critical to Charging
                when externalPower.supply->notEmpty();
            transition Charging to Normal
                when batteryMonitor.status.charge >= 100;
            transition LowPower to Normal
                when batteryMonitor.status.charge >= chargeThreshold;
        }
        
        action def DistributePower {
            in item status : BatteryStatus;
            out item supply : PowerSupply;
            
            perform {
                supply.voltage = 3.7;
                supply.current = 2.0;
            }
        }
        
        action def MonitorBattery {
            in item status : BatteryStatus;
            
            perform {
                if status.charge < 20 {
                    /* Trigger low-power mode */
                }
                if status.charge < 5 {
                    /* Trigger critical mode */
                }
            }
        }
    }
    
    // ===== Top-level Part Definition =====
    
    part def MobileInternetDevice {
        port networkInterface : NetworkPort;
        port externalPowerInput : PowerInputPort;
        
        part processor : ApplicationProcessor {
            :>> clockSpeed = 2000;
            :>> activeProcesses = 0;
            :>> backgroundProcessLimit = 10;
        }
        
        part touchController : TouchInputController {
            :>> sampleRate = 120;
            :>> sensitivity = 0.8;
        }
        
        part displayController : DisplayController {
            :>> resolution = "1080x1920";
            :>> maxBrightness = 500;
            :>> currentBrightness = 300;
        }
        
        part modem : WirelessModem {
            :>> protocol = "LTE";
            :>> signalStrength = 0.0;
            :>> dataRate = 50;
        }
        
        part battery : RechargeableBattery {
            :>> capacity = 10;
            :>> currentCharge = 100;
            :>> nominalVoltage = 3.7;
            :>> health = 100;
            :>> temperature = 298;
        }
        
        part bms : BatteryManagementSystem {
            :>> chargeThreshold = 20;
            :>> criticalThreshold = 5;
            :>> isCharging = false;
        }
        
        // ===== Connections =====
        
        connection touchToProcessor connect touchController.touchOut to processor.touchIn {
            :>> flow touchController.touchOut.events to processor.touchIn.touchEvents;
        }
        
        connection processorToModem connect processor.modemIf to modem.modemIn {
            :>> flow processor.modemIf.requests to modem.modemIn.requests;
            :>> flow modem.modemIn.responses to processor.modemIf.responses;
        }
        
        connection modemToNetwork connect modem.networkIf to networkInterface {
            :>> flow modem.networkIf.outgoingPackets to networkInterface.outgoingPackets;
            :>> flow networkInterface.incomingPackets to modem.networkIf.incomingPackets;
        }
        
        connection processorToDisplay connect processor.displayOut to displayController.displayIn {
            :>> flow processor.displayOut.content to displayController.displayIn.content;
        }
        
        connection batteryToBMS connect battery.monitorOut to bms.batteryMonitor {
            :>> flow battery.monitorOut.status to bms.batteryMonitor.status;
        }
        
        connection bmsToProcessor connect bms.powerDistribution to processor.powerIn {
            :>> flow bms.powerDistribution.supply to processor.powerIn.supply;
        }
        
        connection bmsToTouchController connect bms.powerDistribution to touchController.powerIn {
            :>> flow bms.powerDistribution.supply to touchController.powerIn.supply;
        }
        
        connection bmsToDisplayController connect bms.powerDistribution to displayController.powerIn {
            :>> flow bms.powerDistribution.supply to displayController.powerIn.supply;
        }
        
        connection bmsToModem connect bms.powerDistribution to modem.powerIn {
            :>> flow bms.powerDistribution.supply to modem.powerIn.supply;
        }
        
        connection bmsToProcessorMonitor connect bms.batteryMonitor to processor.batteryMonitor {
            :>> flow bms.batteryMonitor.status to processor.batteryMonitor.status;
        }
        
        connection externalPowerToBMS connect externalPowerInput to bms.externalPower {
            :>> flow externalPowerInput.supply to bms.externalPower.supply;
        }
        
        // ===== Requirement Satisfaction =====
        
        satisfy MobileInternetDeviceRequirements::WebBrowsingCapability by this;
        satisfy MobileInternetDeviceRequirements::TouchInputResponsiveness by touchController;
        satisfy MobileInternetDeviceRequirements::WirelessConnectivity by modem;
        satisfy MobileInternetDeviceRequirements::BatteryLife by bms;
        satisfy MobileInternetDeviceRequirements::LowPowerConservation by bms;
        satisfy MobileInternetDeviceRequirements::CriticalPowerShutdown by bms;
    }
    
    // ===== Operational Scenario =====
    
    action def TypicalBrowsingOperation {
        in device : MobileInternetDevice;
        
        action captureTouch : TouchInputController::CaptureTouch {
            :>> out event;
        }
        
        action processInput : ApplicationProcessor::ProcessTouchInput {
            in event = captureTouch.event;
            :>> out request;
        }
        
        action sendRequest : WirelessModem::SendRequest {
            in request = processInput.request;
            :>> out packet;
        }
        
        action receiveResponse : WirelessModem::ReceiveResponse {
            :>> in packet;
            :>> out response;
        }
        
        action processResponse : ApplicationProcessor::ProcessNetworkResponse {
            in response = receiveResponse.response;
            :>> out content;
        }
        
        action renderContent : DisplayController::RenderContent {
            in content = processResponse.content;
        }
        
        succession captureTouch then processInput;
        succession processInput then sendRequest;
        succession sendRequest then receiveResponse;
        succession receiveResponse then processResponse;
        succession processResponse then renderContent;
    }
}
