package OpenThermHeatingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    doc /* 
    This model describes an OpenTherm-based central heating system that enables digital 
    communication between a room thermostat (master) and a modulating boiler (slave). 
    The primary function is to efficiently regulate indoor temperature by transmitting 
    setpoint commands and receiving real-time status feedback, allowing the boiler to 
    modulate its heat output based on actual demand rather than simple on/off control.
    */
    
    attribute def ModulationLevel :> Real;
    attribute def MessageID :> Integer;
    attribute def DataValue :> Real;
    
    item def OpenThermFrame {
        attribute msgID : MessageID;
        attribute dataValue : DataValue;
        attribute isRequest : Boolean;
    }
    
    item def SetpointMessage :> OpenThermFrame {
        attribute targetTemperature : TemperatureValue;
    }
    
    item def StatusMessage :> OpenThermFrame {
        attribute currentFlowTemperature : TemperatureValue;
        attribute currentReturnTemperature : TemperatureValue;
        attribute modulationLevel : ModulationLevel;
        attribute flameActive : Boolean;
        attribute faultCode : Integer;
    }
    
    port def OpenThermMasterPort {
        out item setpointRequest : SetpointMessage;
        in item statusResponse : StatusMessage;
    }
    
    port def OpenThermSlavePort {
        in item setpointRequest : SetpointMessage;
        out item statusResponse : StatusMessage;
    }
    
    part def RoomThermostat {
        attribute desiredRoomTemperature : TemperatureValue;
        attribute measuredRoomTemperature : TemperatureValue;
        attribute heatingDemand : Boolean;
        
        port otMaster : OpenThermMasterPort;
        
        action def DetermineHeatingDemand {
            in currentTemp : TemperatureValue;
            in setpoint : TemperatureValue;
            out demand : Boolean;
            out calculatedSetpoint : TemperatureValue;
            
            first start;
            then decide;
                if currentTemp < setpoint - 0.5[K] then enableHeating;
                if currentTemp >= setpoint + 0.5[K] then disableHeating;
                else maintainCurrent;
            
            action enableHeating {
                then assign demand := true;
                then assign calculatedSetpoint := 70.0[K];
            }
            then done;
            
            action disableHeating {
                then assign demand := false;
                then assign calculatedSetpoint := 0.0[K];
            }
            then done;
            
            action maintainCurrent {
                then assign demand := heatingDemand;
                then assign calculatedSetpoint := 50.0[K];
            }
            then done;
        }
        
        state def ThermostatControl {
            entry; then monitoring;
            
            state monitoring {
                entry assign heatingDemand := false;
            }
            
            transition monitoring_to_requesting
                first monitoring
                if measuredRoomTemperature < desiredRoomTemperature - 0.5[K]
                then requesting;
            
            state requesting {
                entry assign heatingDemand := true;
                do action sendSetpoint : DetermineHeatingDemand {
                    in currentTemp = measuredRoomTemperature;
                    in setpoint = desiredRoomTemperature;
                    out demand;
                    out calculatedSetpoint;
                }
            }
            
            transition requesting_to_monitoring
                first requesting
                if measuredRoomTemperature >= desiredRoomTemperature
                then monitoring;
        }
    }
    
    part def ModulatingBoiler {
        attribute flowTemperature : TemperatureValue;
        attribute returnTemperature : TemperatureValue;
        attribute currentModulation : ModulationLevel;
        attribute burnerActive : Boolean;
        attribute targetFlowTemperature : TemperatureValue;
        
        port otSlave : OpenThermSlavePort;
        
        action def ProcessSetpoint {
            in receivedSetpoint : SetpointMessage;
            in currentFlow : TemperatureValue;
            out newModulation : ModulationLevel;
            out burnerState : Boolean;
            
            first start;
            then decide;
                if receivedSetpoint.targetTemperature > 0.0[K] then activateBurner;
                else deactivateBurner;
            
            action activateBurner {
                then action calculateModulation {
                    in target : TemperatureValue = receivedSetpoint.targetTemperature;
                    in actual : TemperatureValue = currentFlow;
                    out modLevel : ModulationLevel;
                    
                    first start;
                    then decide;
                        if target - actual > 10.0[K] then fullPower;
                        if target - actual > 5.0[K] then mediumPower;
                        if target - actual > 0.0[K] then lowPower;
                        else minPower;
                    
                    action fullPower {
                        then assign modLevel := 100.0;
                    }
                    then done;
                    
                    action mediumPower {
                        then assign modLevel := 60.0;
                    }
                    then done;
                    
                    action lowPower {
                        then assign modLevel := 30.0;
                    }
                    then done;
                    
                    action minPower {
                        then assign modLevel := 10.0;
                    }
                    then done;
                }
                then assign newModulation := calculateModulation.modLevel;
                then assign burnerState := true;
            }
            then done;
            
            action deactivateBurner {
                then assign newModulation := 0.0;
                then assign burnerState := false;
            }
            then done;
        }
        
        state def BoilerOperation {
            entry; then standby;
            
            state standby {
                entry assign burnerActive := false;
                entry assign currentModulation := 0.0;
            }
            
            transition standby_to_firing
                first standby
                accept sp : SetpointMessage
                if sp.targetTemperature > 0.0[K]
                then firing;
            
            state firing {
                entry assign burnerActive := true;
                
                state modulating {
                    entry; then adjusting;
                    
                    state adjusting {
                        do action modulate : ProcessSetpoint {
                            in receivedSetpoint;
                            in currentFlow = flowTemperature;
                            out newModulation;
                            out burnerState;
                        }
                    }
                    
                    transition adjusting_to_stable
                        first adjusting
                        if flowTemperature >= targetFlowTemperature - 2.0[K]
                        then stable;
                    
                    state stable {
                        entry assign currentModulation := 20.0;
                    }
                    
                    transition stable_to_adjusting
                        first stable
                        if flowTemperature < targetFlowTemperature - 5.0[K]
                        then adjusting;
                }
            }
            
            transition firing_to_standby
                first firing
                accept sp : SetpointMessage
                if sp.targetTemperature == 0.0[K]
                then standby;
        }
    }
    
    part def OpenThermInterface {
        attribute protocolVersion : String;
        attribute messageInterval : DurationValue;
        attribute lastMessageTime : DurationValue;
        
        action def ValidateMessage {
            in frame : OpenThermFrame;
            out validationResult : Boolean;
            
            first start;
            then decide;
                if frame.msgID >= 0 and frame.msgID <= 127 then valid;
                else invalid;
            
            action valid
                then assign validationResult := true;
            then done;
            
            action invalid
                then assign validationResult := false;
            then done;
        }
        
        action def TransmitFrame {
            in outgoingFrame : OpenThermFrame;
            out transmitted : Boolean;
            
            first start;
            then action encode;
            then action transmit;
            then assign transmitted := true;
            then done;
        }
    }
    
    part openThermSystem {
        part thermostat : RoomThermostat {
            attribute :>> desiredRoomTemperature = 294.15[K];
            attribute :>> measuredRoomTemperature = 292.65[K];
        }
        
        part boiler : ModulatingBoiler {
            attribute :>> flowTemperature = 318.15[K];
            attribute :>> returnTemperature = 308.15[K];
            attribute :>> currentModulation = 0.0;
            attribute :>> burnerActive = false;
        }
        
        part interface : OpenThermInterface {
            attribute :>> protocolVersion = "2.2";
            attribute :>> messageInterval = 1.0[s];
        }
        
        connection otConnection connect thermostat.otMaster to boiler.otSlave;
    }
    
    occurrence def OpenThermCommunicationCycle {
        ref part tstat :>> openThermSystem.thermostat;
        ref part boi :>> openThermSystem.boiler;
        
        message setpointCommand of sp : SetpointMessage
            from tstat.otMaster.setpointRequest
            to boi.otSlave.setpointRequest
        {
            sp.targetTemperature = 338.15[K];
            sp.isRequest = true;
        }
        
        then message statusFeedback of st : StatusMessage
            from boi.otSlave.statusResponse
            to tstat.otMaster.statusResponse
        {
            st.currentFlowTemperature = 328.15[K];
            st.modulationLevel = 75.0;
            st.flameActive = true;
            st.faultCode = 0;
        }
    }
    
    requirement def SystemRequirements;
    
    requirement <'OT-REQ-001'> digitalCommunication : SystemRequirements {
        doc /* 
        The OpenTherm system shall provide bidirectional digital communication 
        between the thermostat and boiler using the OpenTherm protocol standard.
        */
        subject system : openThermSystem;
    }
    
    requirement <'OT-REQ-002'> modulatingControl : SystemRequirements {
        doc /* 
        The boiler shall modulate its heat output between 0% and 100% based on 
        the setpoint temperature received from the thermostat.
        */
        subject boiler : openThermSystem.boiler;
    }
    
    requirement <'OT-REQ-003'> temperatureRegulation : SystemRequirements {
        doc /* 
        The system shall maintain room temperature within plus or minus 0.5 K of the 
        thermostat setpoint under normal operating conditions.
        */
    }
    
    requirement <'OT-REQ-004'> responseTime : SystemRequirements {
        doc /* 
        The boiler shall respond to thermostat setpoint changes within 
        1 second of receiving the command.
        */
    }
    
    requirement <'OT-REQ-005'> statusReporting : SystemRequirements {
        doc /* 
        The boiler shall report current flow temperature, modulation level, 
        and operational status to the thermostat at regular intervals.
        */
    }
    
    requirement openThermMission {
        doc /* 
        The OpenTherm heating system shall efficiently regulate indoor climate 
        by enabling intelligent communication and modulating control between 
        thermostat and boiler.
        */
        
        assume constraint validOperatingRange {
            doc /* 
            Room temperature setpoint shall be between 278.15 K and 303.15 K.
            Boiler flow temperature shall not exceed 363.15 K.
            */
        }
        
        require digitalCommunication;
        require modulatingControl;
        require temperatureRegulation;
        require responseTime;
        require statusReporting;
    }
}
