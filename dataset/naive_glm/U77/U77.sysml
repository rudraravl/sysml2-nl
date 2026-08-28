package Ionaco {
    import ScalarValues::*;
    
    // Value Types
    def Voltage :> Real { unit 'V'; }
    def Current :> Real { unit 'A'; }
    def FanSpeed :> Real { unit 'RPM'; }
    def IonizationIntensity :> Real { unit 'kV'; }
    def AirQualityIndex :> Real { unit 'ppm'; }
    def IonConcentration :> Real { unit 'ions/cm3'; }
    
    // Item Types
    item def AmbientAir {
        attribute particulateConcentration : AirQualityIndex;
    }
    item def FilteredAir {
        attribute particulateConcentration : AirQualityIndex;
    }
    item def IonizedAir {
        attribute ionConcentration : IonConcentration;
        attribute particulateConcentration : AirQualityIndex;
    }
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    
    // Port Types
    port def AirFlowPort {
        out item : AmbientAir;
    }
    port def FilteredAirPort {
        out item : FilteredAir;
    }
    port def IonizedAirPort {
        out item : IonizedAir;
    }
    port def PowerPort {
        out item : ElectricalPower;
    }
    port def ControlSignalPort {
        out attribute fanSpeed : FanSpeed;
        out attribute ionizationIntensity : IonizationIntensity;
    }
    port def SensorFeedbackPort {
        out attribute airQuality : AirQualityIndex;
        out attribute ionConcentration : IonConcentration;
    }
    
    // Part Definitions
    part def IntakeFan {
        port airIn : AirFlowPort;
        port airOut : AirFlowPort;
        port powerIn : PowerPort;
        port controlIn : ControlSignalPort;
        
        attribute currentSpeed : FanSpeed;
        
        action def PullAir {
            in air : AmbientAir;
            out outAir : AmbientAir;
        }
    }
    
    part def HEPAFilter {
        port airIn : AirFlowPort;
        port airOut : FilteredAirPort;
        
        action def FilterParticulates {
            in air : AmbientAir;
            out filteredAir : FilteredAir;
        }
    }
    
    part def IonizationModule {
        port airIn : FilteredAirPort;
        port airOut : IonizedAirPort;
        port powerIn : PowerPort;
        port controlIn : ControlSignalPort;
        
        attribute currentIntensity : IonizationIntensity;
        
        action def IonizeAir {
            in filteredAir : FilteredAir;
            out ionizedAir : IonizedAir;
        }
    }
    
    part def DistributionFan {
        port airIn : IonizedAirPort;
        port airOut : IonizedAirPort;
        port powerIn : PowerPort;
        port controlIn : ControlSignalPort;
        
        attribute currentSpeed : FanSpeed;
        attribute oscillating : Boolean;
        
        action def CirculateAir {
            in ionizedAir : IonizedAir;
            out distributedAir : IonizedAir;
        }
    }
    
    part def AirQualitySensor {
        port airIn : AirFlowPort;
        port feedbackOut : SensorFeedbackPort;
        port powerIn : PowerPort;
        
        action def MeasureAirQuality {
            in air : AmbientAir;
            out qualityIndex : AirQualityIndex;
        }
    }
    
    part def IonSensor {
        port airIn : IonizedAirPort;
        port feedbackOut : SensorFeedbackPort;
        port powerIn : PowerPort;
        
        action def MeasureIonConcentration {
            in air : IonizedAir;
            out concentration : IonConcentration;
        }
    }
    
    part def PowerManagementUnit {
        port mainPowerIn : PowerPort;
        port fanPowerOut : PowerPort;
        port sensorPowerOut : PowerPort;
        port ionizerPowerOut : PowerPort;
        port processorPowerOut : PowerPort;
        
        action def DistributePower {
            in mainPower : ElectricalPower;
            out distributedPower : ElectricalPower;
        }
    }
    
    part def ControlProcessor {
        port powerIn : PowerPort;
        port airSensorIn : SensorFeedbackPort;
        port ionSensorIn : SensorFeedbackPort;
        port intakeFanControlOut : ControlSignalPort;
        port distFanControlOut : ControlSignalPort;
        port ionizerControlOut : ControlSignalPort;
        
        state machine ControlStateMachine {
            initial Off;
            state Standby;
            state Active {
                state Low;
                state Medium;
                state High;
                state Auto;
            }
            state Maintenance;
            
            transition off_to_standby first Off then Standby;
            transition standby_to_active first Standby then Active;
            transition active_to_standby first Active then Standby;
            transition any_to_maintenance first (Off, Standby, Active) then Maintenance;
            transition maintenance_to_off first Maintenance then Off;
        }
        
        action def ProcessFeedback {
            in airQuality : AirQualityIndex;
            in ionConcentration : IonConcentration;
            out fanSpeed : FanSpeed;
            out ionizationIntensity : IonizationIntensity;
        }
    }
    
    part def IonacoSystem {
        port externalPowerIn : PowerPort;
        port ambientAirIn : AirFlowPort;
        port ionizedAirOut : IonizedAirPort;
        
        part intakeFan : IntakeFan;
        part hepaFilter : HEPAFilter;
        part ionizationModule : IonizationModule;
        part distributionFan : DistributionFan;
        part airQualitySensor : AirQualitySensor;
        part ionSensor : IonSensor;
        part powerManagementUnit : PowerManagementUnit;
        part controlProcessor : ControlProcessor;
        
        // Air Flow Connections
        connection ambientToIntake connect ambientAirIn to intakeFan.airIn;
        connection intakeToFilter connect intakeFan.airOut to hepaFilter.airIn;
        connection filterToIonizer connect hepaFilter.airOut to ionizationModule.airIn;
        connection ionizerToDistFan connect ionizationModule.airOut to distributionFan.airIn;
        connection distToAmbient connect distributionFan.airOut to ionizedAirOut;
        
        // Sensor Air Flow Connections
        connection intakeToAirSensor connect intakeFan.airOut to airQualitySensor.airIn;
        connection distToIonSensor connect distributionFan.airOut to ionSensor.airIn;
        
        // Power Connections
        connection extToPMU connect externalPowerIn to powerManagementUnit.mainPowerIn;
        connection pmuToIntakeFan connect powerManagementUnit.fanPowerOut to intakeFan.powerIn;
        connection pmuToDistFan connect powerManagementUnit.fanPowerOut to distributionFan.powerIn;
        connection pmuToIonizer connect powerManagementUnit.ionizerPowerOut to ionizationModule.powerIn;
        connection pmuToAirSensor connect powerManagementUnit.sensorPowerOut to airQualitySensor.powerIn;
        connection pmuToIonSensor connect powerManagementUnit.sensorPowerOut to ionSensor.powerIn;
        connection pmuToProcessor connect powerManagementUnit.processorPowerOut to controlProcessor.powerIn;
        
        // Control Connections
        connection procToIntakeFan connect controlProcessor.intakeFanControlOut to intakeFan.controlIn;
        connection procToDistFan connect controlProcessor.distFanControlOut to distributionFan.controlIn;
        connection procToIonizer connect controlProcessor.ionizerControlOut to ionizationModule.controlIn;
        
        // Feedback Connections
        connection airSensorToProc connect airQualitySensor.feedbackOut to controlProcessor.airSensorIn;
        connection ionSensorToProc connect ionSensor.feedbackOut to controlProcessor.ionSensorIn;
    }
    
    requirement def AirPurificationRequirement {
        subject system : IonacoSystem;
        objective {
            doc /* The system shall purify and ionize ambient air and distribute it back into the room. */
        }
        require system.intakeFan;
        require system.hepaFilter;
        require system.ionizationModule;
        require system.distributionFan;
    }
}
