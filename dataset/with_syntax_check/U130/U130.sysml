package TranscranialMagneticStimulationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def StimulationProtocol {
        attribute intensity : Real;
        attribute frequency : Real;
        attribute duration : Real;
        attribute pulseCount : Integer;
    }
    
    attribute def CalibrationRequest;
    attribute def SessionComplete;
    attribute def SystemReset;
    
    item def MagneticPulse;
    item def CoolantFlow;
    item def ControlSignal;
    
    port def MagneticFieldPort {
        out fieldStrength : ISQ::MagneticFluxDensityValue;
    }
    
    port def PowerPort {
        in powerDemand : ISQ::PowerValue;
        out powerSupply : ISQ::PowerValue;
    }
    
    port def CoolingPort {
        in heatLoad : ISQ::PowerValue;
        out temperature : ISQ::ThermodynamicTemperatureValue;
    }
    
    port def ControlPort {
        in protocol : StimulationProtocol;
        out pulseCommand : ControlSignal;
    }
    
    port def PositionPort {
        in targetLocation : ISQ::LengthValue[3];
        out currentPosition : ISQ::LengthValue[3];
    }
    
    port def SafetyPort {
        in coilTemp : ISQ::ThermodynamicTemperatureValue;
        in fieldStrength : ISQ::MagneticFluxDensityValue;
        out safetyStatus : Boolean;
    }
    
    part def StimulationCoil {
        attribute maxFieldStrength : ISQ::MagneticFluxDensityValue;
        attribute coilResistance : ISQ::ResistanceValue;
        attribute inductance : ISQ::InductanceValue;
        attribute currentTemperature : ISQ::ThermodynamicTemperatureValue;
        
        port fieldOutput : MagneticFieldPort;
        port powerInput : PowerPort;
        port coolingInterface : CoolingPort;
    }
    
    part def PowerSupply {
        attribute maxCurrent : ISQ::ElectricCurrentValue;
        attribute maxVoltage : ISQ::PotentialValue;
        attribute capacitorBank : ISQ::CapacitanceValue;
        
        port powerOutput : PowerPort;
    }
    
    part def CoolingSystem {
        attribute coolantFlowRate : ISQ::VolumeFlowRateValue;
        attribute maxCoolingPower : ISQ::PowerValue;
        
        port coolingOutput : CoolingPort;
    }
    
    part def ControlUnit {
        attribute activeProtocol : StimulationProtocol;
        
        port controlInterface : ControlPort;
    }
    
    part def PositioningArm {
        attribute degreesOfFreedom : Integer;
        attribute positionAccuracy : ISQ::LengthValue;
        
        port positionInterface : PositionPort;
    }
    
    part def SafetyMonitor {
        attribute maxTemperatureThreshold : ISQ::ThermodynamicTemperatureValue;
        attribute maxFieldThreshold : ISQ::MagneticFluxDensityValue;
        attribute maxPulseCount : Integer;
        
        port monitoringInterface : SafetyPort;
    }
    
    action def CalibrateMotorThreshold {
        in initialIntensity : Real;
        out determinedThreshold : Real;
    }
    
    action def PositionCoil {
        in targetBrainRegion : ISQ::LengthValue[3];
        in coilOrientation : Real;
        out finalPosition : ISQ::LengthValue[3];
        out finalAlignment : Real;
    }
    
    action def GenerateMagneticPulse {
        in pulseIntensity : Real;
        in pulseDuration : ISQ::DurationValue;
        out fieldStrength : ISQ::MagneticFluxDensityValue;
        out energyConsumed : ISQ::EnergyValue;
    }
    
    action def MonitorSafety {
        in currentTemperature : ISQ::ThermodynamicTemperatureValue;
        in currentFieldStrength : ISQ::MagneticFluxDensityValue;
        in totalPulses : Integer;
        out isSafe : Boolean;
    }
    
    action def CoolCoil {
        in heatGenerated : ISQ::PowerValue;
        in targetTemperature : ISQ::ThermodynamicTemperatureValue;
        out actualTemperature : ISQ::ThermodynamicTemperatureValue;
    }
    
    state def TMSOperationalStates {
        in attribute systemReady : Boolean;
        in attribute calibThreshold : Real;
        in attribute alignmentAngle : Real;
        in attribute safetyOk : Boolean;
        
        entry; then idle;
        
        state idle;
        
        transition idle_to_calibration
            first idle
            accept CalibrationRequest
            then calibration;
        
        state calibration {
            entry; then performCalibration;
            do action performCalibration : CalibrateMotorThreshold;
        }
        
        transition calibration_to_positioning
            first calibration
            if calibThreshold > 0.0
            then positioning;
        
        state positioning {
            entry; then positionCoil;
            do action positionCoil : PositionCoil;
        }
        
        transition positioning_to_stimulation
            first positioning
            if alignmentAngle < 5.0
            then stimulation;
        
        state stimulation parallel {
            state pulseGeneration {
                entry; then generatePulses;
                do action generatePulses : GenerateMagneticPulse;
            }
            
            state safetyMonitoring {
                entry; then monitorSafety;
                do action monitorSafety : MonitorSafety;
            }
            
            state thermalManagement {
                entry; then coolCoil;
                do action coolCoil : CoolCoil;
            }
        }
        
        transition stimulation_to_idle
            first stimulation
            accept SessionComplete
            then idle;
        
        transition emergency_shutdown
            first stimulation
            if not safetyOk
            then emergencyStop;
        
        state emergencyStop;
        
        transition emergencyStop_to_idle
            first emergencyStop
            accept SystemReset
            then idle;
    }
    
    action def DeliverTMSTherapy {
        in treatmentProtocol : StimulationProtocol;
        in targetRegion : ISQ::LengthValue[3];
        out treatmentComplete : Boolean;
        
        private attribute pulseCountComplete : Boolean;
        
        first start;
        then action calibrate : CalibrateMotorThreshold {
            in initialIntensity : Real;
            out determinedThreshold : Real;
        }
        then action position : PositionCoil {
            in targetBrainRegion = targetRegion;
            in coilOrientation : Real;
            out finalPosition : ISQ::LengthValue[3];
            out finalAlignment : Real;
        }
        then merge stimulationLoop;
        
        action stimulationLoop {
            first action checkSafety : MonitorSafety {
                in currentTemperature : ISQ::ThermodynamicTemperatureValue;
                in currentFieldStrength : ISQ::MagneticFluxDensityValue;
                in totalPulses : Integer;
                out isSafe : Boolean;
            }
            then decide;
                if checkSafety.isSafe then deliverPulse;
                if not checkSafety.isSafe then abort;
            
            action deliverPulse parallel {
                action generatePulse : GenerateMagneticPulse {
                    in pulseIntensity = calibrate.determinedThreshold;
                    in pulseDuration : ISQ::DurationValue;
                    out fieldStrength : ISQ::MagneticFluxDensityValue;
                    out energyConsumed : ISQ::EnergyValue;
                }
                action cool : CoolCoil {
                    in heatGenerated : ISQ::PowerValue;
                    in targetTemperature : ISQ::ThermodynamicTemperatureValue;
                    out actualTemperature : ISQ::ThermodynamicTemperatureValue;
                }
            }
            then decide;
                if pulseCountComplete then complete;
                if not pulseCountComplete then stimulationLoop;
            
            action complete {
                assign treatmentComplete := true;
            }
            then done;
            
            action abort {
                assign treatmentComplete := false;
            }
            then done;
        }
    }
    
    part def TMSSystem {
        attribute sessionActive : Boolean;
        attribute totalPulsesDelivered : Integer;
        
        part magneticCoil : StimulationCoil {
            attribute :>> maxFieldStrength : ISQ::MagneticFluxDensityValue;
            attribute :>> coilResistance : ISQ::ResistanceValue;
            attribute :>> inductance : ISQ::InductanceValue;
            attribute :>> currentTemperature : ISQ::ThermodynamicTemperatureValue;
        }
        
        part powerSupply : PowerSupply {
            attribute :>> maxCurrent : ISQ::ElectricCurrentValue;
            attribute :>> maxVoltage : ISQ::PotentialValue;
            attribute :>> capacitorBank : ISQ::CapacitanceValue;
        }
        
        part coolingSystem : CoolingSystem {
            attribute :>> coolantFlowRate : ISQ::VolumeFlowRateValue;
            attribute :>> maxCoolingPower : ISQ::PowerValue;
        }
        
        part controlUnit : ControlUnit {
            attribute :>> activeProtocol : StimulationProtocol;
        }
        
        part positioningArm : PositioningArm {
            attribute :>> degreesOfFreedom = 6;
            attribute :>> positionAccuracy : ISQ::LengthValue;
        }
        
        part safetyMonitor : SafetyMonitor {
            attribute :>> maxTemperatureThreshold : ISQ::ThermodynamicTemperatureValue;
            attribute :>> maxFieldThreshold : ISQ::MagneticFluxDensityValue;
            attribute :>> maxPulseCount = 3000;
        }
        
        connect powerSupply.powerOutput to magneticCoil.powerInput;
        connect coolingSystem.coolingOutput to magneticCoil.coolingInterface;
        
        perform action deliverTherapy : DeliverTMSTherapy {
            in treatmentProtocol : StimulationProtocol;
            in targetRegion : ISQ::LengthValue[3];
            out treatmentComplete : Boolean;
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The TMS system shall ensure patient safety during operation. */
        subject tmsSystem : TMSSystem;
    }
    
    requirement def TemperatureSafetyRequirement :> SafetyRequirement {
        doc /* The magnetic coil temperature shall not exceed 40 degrees Celsius during operation. */
        subject coil : StimulationCoil;
    }
    
    requirement def FieldStrengthRequirement {
        doc /* The system shall generate magnetic field strength between 1.0 and 2.5 Tesla. */
        subject coil : StimulationCoil;
    }
    
    requirement def PositioningAccuracyRequirement {
        doc /* The positioning system shall achieve accuracy within 1 millimeter. */
        subject arm : PositioningArm;
    }
    
    requirement def TherapyDeliveryRequirement {
        doc /* The system shall deliver transcranial magnetic stimulation to modulate neural activity in targeted brain regions. */
        subject system : TMSSystem;
    }
    
    part tmsSystem : TMSSystem {
        part magneticCoil {
            perform deliverTherapy.generatePulse;
        }
        
        part coolingSystem {
            perform deliverTherapy.cool;
        }
        
        part controlUnit {
            perform deliverTherapy.calibrate;
        }
        
        part positioningArm {
            perform deliverTherapy.position;
        }
        
        part safetyMonitor {
            perform deliverTherapy.checkSafety;
        }
    }
}
