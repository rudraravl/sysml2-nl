package PhotoresistorLightSensingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def IlluminanceValue :> Real {
        doc /* Illuminance measured in lux */
    }
    
    attribute def ResistanceValue :> Real {
        doc /* Electrical resistance measured in ohms */
    }
    
    attribute def VoltageValue :> Real {
        doc /* Voltage measured in volts */
    }
    
    attribute def CurrentValue :> Real {
        doc /* Current measured in amperes */
    }
    
    enum def LightCondition {
        dark;
        dim;
        bright;
    }
    
    item def LightSignal {
        attribute illuminance : IlluminanceValue;
    }
    
    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    port def LightInputPort {
        in lightSignal : LightSignal;
    }
    
    port def ElectricalOutputPort {
        out electricalSignal : ElectricalSignal;
    }
    
    port def PowerPort {
        in supplyVoltage : VoltageValue;
    }
    
    part def Photoresistor {
        doc /* 
            Light-dependent resistor whose resistance decreases 
            with increasing incident light intensity 
        */
        
        attribute darkResistance : ResistanceValue := 1000000.0;
        attribute brightResistance : ResistanceValue := 1000.0;
        attribute currentResistance : ResistanceValue;
        attribute gamma : Real := 0.7;
        
        port lightIn : LightInputPort;
        
        action def ConvertLightToResistance {
            in illuminance : IlluminanceValue;
            in rDark : ResistanceValue;
            in rBright : ResistanceValue;
            in gammaFactor : Real;
            out resistance : ResistanceValue;
            
            doc /* 
                Calculate resistance based on light intensity using 
                exponential relationship: R = R_dark * (lux / lux_ref)^(-gamma) 
            */
        }
        
        perform action sensing : ConvertLightToResistance {
            in illuminance = lightIn.lightSignal.illuminance;
            in rDark = darkResistance;
            in rBright = brightResistance;
            in gammaFactor = gamma;
            out resistance;
        }
    }
    
    part def VoltageDividerCircuit {
        doc /* 
            Converts variable photoresistor resistance to 
            proportional voltage output 
        */
        
        attribute fixedResistance : ResistanceValue := 10000.0;
        attribute supplyVoltage : VoltageValue := 5.0;
        attribute outputVoltage : VoltageValue;
        
        port powerIn : PowerPort;
        port signalOut : ElectricalOutputPort;
        
        action def CalculateDividerVoltage {
            in vSupply : VoltageValue;
            in rFixed : ResistanceValue;
            in rVariable : ResistanceValue;
            out vOut : VoltageValue;
            
            doc /* Vout = Vsupply * (R_fixed / (R_fixed + R_variable)) */
        }
    }
    
    part def SignalConditioner {
        doc /* 
            Processes voltage signal to determine light condition 
            and provide digital output 
        */
        
        attribute lowThreshold : VoltageValue := 1.5;
        attribute highThreshold : VoltageValue := 3.5;
        attribute currentCondition : LightCondition;
        
        port analogIn : ElectricalOutputPort;
        
        action def ClassifyLightLevel {
            in inputVoltage : VoltageValue;
            in thresholdLow : VoltageValue;
            in thresholdHigh : VoltageValue;
            out condition : LightCondition;
        }
        
        state def LightDetectionStateMachine {
            entry; then darkState;
            
            state darkState {
                entry action setDark {
                    bind currentCondition = LightCondition::dark;
                }
            }
            
            transition darkToDim
                first darkState
                accept signal : ElectricalSignal
                if signal.voltage > lowThreshold
                then dimState;
            
            state dimState {
                entry action setDim {
                    bind currentCondition = LightCondition::dim;
                }
            }
            
            transition dimToDark
                first dimState
                accept signal : ElectricalSignal
                if signal.voltage <= lowThreshold
                then darkState;
            
            transition dimToBright
                first dimState
                accept signal : ElectricalSignal
                if signal.voltage > highThreshold
                then brightState;
            
            state brightState {
                entry action setBright {
                    bind currentCondition = LightCondition::bright;
                }
            }
            
            transition brightToDim
                first brightState
                accept signal : ElectricalSignal
                if signal.voltage <= highThreshold
                then dimState;
        }
        
        exhibit state behavior : LightDetectionStateMachine;
    }
    
    part def LightSensingModule {
        doc /* 
            Complete light sensing assembly integrating photoresistor, 
            voltage divider, and signal conditioning 
        */
        
        attribute operatingVoltage : VoltageValue := 5.0;
        attribute measuredIlluminance : IlluminanceValue;
        attribute outputVoltage : VoltageValue;
        attribute detectedCondition : LightCondition;
        
        port lightPort : LightInputPort;
        port powerPort : PowerPort;
        
        part sensor : Photoresistor {
            port redefines lightIn;
        }
        
        part divider : VoltageDividerCircuit {
            port redefines powerIn;
            port redefines signalOut;
        }
        
        part conditioner : SignalConditioner {
            port redefines analogIn;
        }
        
        connection sensorToDivider connect 
            sensor to divider;
        
        connection dividerToConditioner connect 
            divider.signalOut to conditioner.analogIn;
        
        connection externalLight connect 
            lightPort to sensor.lightIn;
        
        connection externalPower connect 
            powerPort to divider.powerIn;
        
        bind measuredIlluminance = sensor.lightIn.lightSignal.illuminance;
        bind outputVoltage = divider.outputVoltage;
        bind detectedCondition = conditioner.currentCondition;
    }
    
    action def MonitorAmbientLight {
        in currentIlluminance : IlluminanceValue;
        out sensorVoltage : VoltageValue;
        out lightLevel : LightCondition;
    }
    
    action def UpdateLightReading {
        in illuminance : IlluminanceValue;
        out resistance : ResistanceValue;
        out voltage : VoltageValue;
    }
    
    action def ContinuousLightSensing {
        doc /* 
            Primary system behavior: continuously monitor ambient light 
            and convert to electrical signals for downstream applications 
        */
        
        in ambientIlluminance : IlluminanceValue;
        out analogOutput : VoltageValue;
        out digitalOutput : LightCondition;
        
        first start;
        then merge continuousSensing;
        
        then action monitor : MonitorAmbientLight {
            in currentIlluminance = ambientIlluminance;
            out sensorVoltage;
            out lightLevel;
        }
        
        then action update : UpdateLightReading {
            in illuminance = ambientIlluminance;
            out resistance;
            out voltage;
        }
        
        then continuousSensing;
    }
    
    part photoresistorSystem : LightSensingModule {
        doc /* 
            Photoresistor-based light sensing system that automatically 
            detects and measures ambient light intensity.
            
            Primary Function: Convert varying ambient light levels into 
            proportional electrical signals (both analog voltage and digital 
            light condition states) for use in automated lighting control, 
            day/night detection, solar tracking, camera exposure control, 
            and other light-responsive applications.
            
            The system operates by utilizing a photoresistor whose resistance 
            varies inversely with incident light intensity. This resistance 
            change is converted to a voltage signal through a voltage divider 
            circuit, then processed to determine discrete light conditions 
            (dark, dim, bright) for digital control applications.
        */
        
        perform action lightSensingBehavior : ContinuousLightSensing;
        
        part redefines sensor : Photoresistor;
        part redefines divider : VoltageDividerCircuit;
        part redefines conditioner : SignalConditioner;
    }
    
    requirement def SensingAccuracyRequirement {
        doc /* 
            System shall accurately convert light intensity to 
            electrical signals across operating range 
        */
        
        subject system : LightSensingModule;
        
        require constraint {
            doc /* 
                Photoresistor resistance shall vary from dark to bright 
                resistance within specified range 
            */
            system.sensor.currentResistance >= system.sensor.brightResistance and
            system.sensor.currentResistance <= system.sensor.darkResistance
        }
    }
    
    requirement def OutputRangeRequirement {
        doc /* 
            System output voltage shall remain within valid range 
            for all light conditions 
        */
        
        subject system : LightSensingModule;
        
        require constraint {
            doc /* Output voltage shall be between 0V and supply voltage */
            system.outputVoltage >= 0.0 and
            system.outputVoltage <= system.operatingVoltage
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* 
            System shall respond to light changes within 
            acceptable time period 
        */
        
        subject system : LightSensingModule;
    }
    
    requirement <'PHOTO-SYS-001'> primarySystemRequirement {
        doc /* 
            The photoresistor light sensing system shall continuously 
            monitor ambient light levels and provide both analog voltage 
            output proportional to illuminance and digital state output 
            indicating light condition for automated control applications.
        */
        
        require constraint sensingAccuracyConstraint : SensingAccuracyRequirement;
        require constraint outputRangeConstraint : OutputRangeRequirement;
        require constraint responseTimeConstraint : ResponseTimeRequirement;
    }
}
