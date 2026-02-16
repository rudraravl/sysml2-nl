package RheotraumaSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ShearStressValue :> ISQ::PressureValue;
    attribute def ViscosityValue :> ISQ::DynamicViscosityValue;
    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def DamageIndexValue :> Real;
    attribute def CellViabilityValue :> Real;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    
    item def BloodSample {
        attribute hemoglobinLevel : Real;
        attribute hematocrit : Real;
        attribute cellDamageIndex : DamageIndexValue;
        attribute viability : CellViabilityValue;
    }
    
    item def FluidStream {
        attribute shearStress : ShearStressValue;
        attribute flowRate : FlowRateValue;
        attribute viscosity : ViscosityValue;
        attribute temperature : TemperatureValue;
    }
    
    item def ControlSignal;
    item def ElectricalPower;
    item def SensorData;
    
    port def FluidInletPort {
        in item fluidIn : FluidStream;
    }
    
    port def FluidOutletPort {
        out item fluidOut : FluidStream;
    }
    
    port def SamplePort {
        in item sampleIn : BloodSample;
        out item sampleOut : BloodSample;
    }
    
    port def PowerPort {
        in item power : ElectricalPower;
    }
    
    port def ControlPort {
        in item controlSignal : ControlSignal;
    }
    
    port def DataPort {
        out item sensorData : SensorData;
    }
    
    part def PrecisionPump {
        port powerIn : PowerPort;
        port controlIn : ControlPort;
        port fluidIn : FluidInletPort;
        port fluidOut : FluidOutletPort;
        attribute currentSpeed : ISQ::AngularVelocityValue;
        attribute maxFlowRate : FlowRateValue;
    }
    
    part def ShearChamber {
        doc /* Microfluidic chamber designed to generate controlled shear stress on blood samples. */
        port fluidIn : FluidInletPort;
        port fluidOut : FluidOutletPort;
        port sampleIn : SamplePort;
        port dataOut : DataPort;
        attribute chamberGeometry : Real;
        attribute wallShearStress : ShearStressValue;
        attribute exposureTime : ISQ::TimeValue;
    }
    
    part def ShearStressSensor {
        port fluidMonitor : FluidInletPort;
        port dataOut : DataPort;
        attribute measuredShearStress : ShearStressValue;
        attribute accuracy : Real;
    }
    
    part def TemperatureController {
        port powerIn : PowerPort;
        port controlIn : ControlPort;
        port dataOut : DataPort;
        attribute targetTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
    }
    
    part def FlowRateSensor {
        port fluidMonitor : FluidInletPort;
        port dataOut : DataPort;
        attribute measuredFlowRate : FlowRateValue;
    }
    
    part def DamageAnalyzer {
        port sampleIn : SamplePort;
        port dataOut : DataPort;
        attribute damageThreshold : DamageIndexValue;
        attribute analysisResolution : Real;
    }
    
    attribute def CalibrationCommand;
    attribute def CalibrationComplete;
    attribute def StartExperiment;
    attribute def ExperimentComplete;
    attribute def DataSaved;
    attribute def CriticalFault;
    attribute def MaintenanceComplete;
    
    part def SystemController {
        port powerIn : PowerPort;
        port sensorDataIn : DataPort[*];
        port pumpControlOut : ControlPort;
        port tempControlOut : ControlPort;
        
        state def ControlStateMachine {
            entry; then initialization;
            
            state initialization;
            then standby;
            
            state standby;
            accept calibrationCmd : CalibrationCommand;
            then calibration;
            
            state calibration;
            accept calibrationDone : CalibrationComplete;
            then standby;
            
            accept startExp : StartExperiment;
            then experimentRunning;
            
            state experimentRunning;
            accept expComplete : ExperimentComplete;
            then dataCollection;
            
            accept fault : CriticalFault;
            then emergencyShutdown;
            
            state dataCollection;
            accept dataSaved : DataSaved;
            then standby;
            
            state emergencyShutdown;
            then maintenance;
            
            state maintenance;
            accept maintComplete : MaintenanceComplete;
            then standby;
        }
    }
    
    part def FluidReservoir {
        port fluidIn : FluidInletPort;
        port fluidOut : FluidOutletPort;
        attribute capacity : ISQ::VolumeValue;
        attribute currentLevel : ISQ::VolumeValue;
    }
    
    action def MeasureShearStress {
        in flowConditions : FluidStream;
        in chamberGeometry : Real;
        out shearStress : ShearStressValue;
    }
    
    action def AssessBloodDamage {
        in shearStress : ShearStressValue;
        in exposureTime : ISQ::TimeValue;
        in bloodSample : BloodSample;
        out damageIndex : DamageIndexValue;
        out viability : CellViabilityValue;
    }
    
    action def AdjustFlowRate {
        in targetShearStress : ShearStressValue;
        in currentShearStress : ShearStressValue;
        in currentFlowRate : FlowRateValue;
        out adjustedFlowRate : FlowRateValue;
    }
    
    action def RegulateTemperature {
        in targetTemp : TemperatureValue;
        in currentTemp : TemperatureValue;
        out heatingPower : ISQ::PowerValue;
    }
    
    action def ConductRheotraumaExperiment {
        doc /* Primary action to conduct controlled rheotrauma experiment on blood sample. */
        in targetShearStress : ShearStressValue;
        in experimentDuration : ISQ::TimeValue;
        in testSample : BloodSample;
        out finalDamageIndex : DamageIndexValue;
        out shearStressProfile : ShearStressValue[*];
        out viabilityProfile : CellViabilityValue[*];
        
        private attribute currentShearStress : ShearStressValue;
        private attribute currentFlowRate : FlowRateValue;
        private attribute currentTemp : TemperatureValue;
        private attribute stressHistory : ShearStressValue[*] := ( );
        private attribute viabilityHistory : CellViabilityValue[*] := ( );
        
        first start;
        then action initialize {
            action calibrateSensors;
            then action primeFluidPath;
            then action loadSample;
        }
        then merge experimentLoop;
        
        then loop for timeStep in 1..experimentDuration {
            action measureConditions {
                perform measureShear : MeasureShearStress {
                    in flowConditions;
                    in chamberGeometry = 1.5;
                    out shearStress;
                }
                then assign currentShearStress := measureShear.shearStress;
            }
            
            then action assessDamage : AssessBloodDamage {
                in shearStress = currentShearStress;
                in exposureTime = timeStep;
                in bloodSample = testSample;
                out damageIndex;
                out viability;
            }
            
            then assign stressHistory := stressHistory->including(currentShearStress);
            then assign viabilityHistory := viabilityHistory->including(assessDamage.viability);
            
            then decide;
                if currentShearStress < targetShearStress then increaseFlow;
                if currentShearStress > targetShearStress then decreaseFlow;
                else maintainFlow;
            
            action increaseFlow : AdjustFlowRate {
                in targetShearStress = targetShearStress;
                in currentShearStress = currentShearStress;
                in currentFlowRate = currentFlowRate;
                out adjustedFlowRate;
            }
            then assign currentFlowRate := increaseFlow.adjustedFlowRate;
            then maintainFlow;
            
            action decreaseFlow : AdjustFlowRate {
                in targetShearStress = targetShearStress;
                in currentShearStress = currentShearStress;
                in currentFlowRate = currentFlowRate;
                out adjustedFlowRate;
            }
            then assign currentFlowRate := decreaseFlow.adjustedFlowRate;
            then maintainFlow;
            
            action maintainFlow;
            
            then action regulateTemp : RegulateTemperature {
                in targetTemp = 310.15[SI::K];
                in currentTemp = currentTemp;
                out heatingPower;
            }
            
            then experimentLoop;
        }
        
        then action finalizeExperiment {
            action stopFlow;
            then action collectFinalSample;
            then assign finalDamageIndex := viabilityHistory->last();
            then assign shearStressProfile := stressHistory;
            then assign viabilityProfile := viabilityHistory;
        }
        then done;
    }
    
    part def RheotraumaTestSystem {
        doc /* System for inducing and quantifying mechanical blood damage through controlled shear stress exposure. */
        
        attribute maxShearStress : ShearStressValue;
        attribute operatingTemperature : TemperatureValue;
        attribute experimentalAccuracy : Real;
        
        port sampleInput : SamplePort;
        port sampleOutput : SamplePort;
        port mainPower : PowerPort;
        
        part controller : SystemController {
            exhibit state controlStateMachine : ControlStateMachine;
        }
        
        part pump : PrecisionPump {
            :>> maxFlowRate = 100.0[SI::ml/SI::min];
        }
        
        part chamber : ShearChamber {
            :>> chamberGeometry = 1.5;
            :>> exposureTime = 300.0[SI::s];
        }
        
        part reservoir : FluidReservoir {
            :>> capacity = 500.0[SI::ml];
        }
        
        part shearSensor : ShearStressSensor {
            :>> accuracy = 0.02;
        }
        
        part flowSensor : FlowRateSensor;
        
        part tempController : TemperatureController {
            :>> targetTemperature = 310.15[SI::K];
        }
        
        part analyzer : DamageAnalyzer {
            :>> damageThreshold = 0.05;
            :>> analysisResolution = 0.001;
        }
        
        item flow powerDistribution : ElectricalPower
            from mainPower to pump.powerIn,
            from mainPower to controller.powerIn,
            from mainPower to tempController.powerIn;
        
        item flow pumpControl : ControlSignal
            from controller.pumpControlOut to pump.controlIn;
        
        item flow tempControl : ControlSignal
            from controller.tempControlOut to tempController.controlIn;
        
        item flow sensorFeedback : SensorData
            from shearSensor.dataOut to controller.sensorDataIn,
            from flowSensor.dataOut to controller.sensorDataIn,
            from tempController.dataOut to controller.sensorDataIn,
            from analyzer.dataOut to controller.sensorDataIn;
        
        connection fluidPath1 connect reservoir.fluidOut to pump.fluidIn;
        connection fluidPath2 connect pump.fluidOut to chamber.fluidIn;
        connection fluidPath3 connect chamber.fluidOut to reservoir.fluidIn;
        
        connection samplePath1 connect sampleInput to chamber.sampleIn;
        connection samplePath2 connect chamber.sampleIn to analyzer.sampleIn;
        connection samplePath3 connect analyzer.sampleIn to sampleOutput;
        
        item flow fluidCirculation : FluidStream
            from reservoir.fluidOut to pump.fluidIn,
            from pump.fluidOut to chamber.fluidIn,
            from chamber.fluidOut to reservoir.fluidIn;
        
        item flow sampleProcessing : BloodSample
            from sampleInput to chamber.sampleIn,
            from chamber.sampleIn to analyzer.sampleIn,
            from analyzer.sampleIn to sampleOutput;
        
        perform action runExperiment : ConductRheotraumaExperiment;
    }
    
    requirement def ShearStressControlRequirement {
        doc /* The system shall maintain shear stress within ±5% of target value during experiment. */
        require constraint {
            abs(chamber.wallShearStress - targetShearStress) <= 0.05 * targetShearStress
        }
    }
    
    requirement def TemperatureStabilityRequirement {
        doc /* The system shall maintain sample temperature at 37°C ±0.5°C throughout experiment. */
        require constraint {
            abs(tempController.currentTemperature - 310.15[SI::K]) <= 0.5[SI::K]
        }
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* The system shall measure shear stress with accuracy better than 2% of reading. */
        require constraint {
            shearSensor.accuracy <= 0.02
        }
    }
    
    requirement def DamageQuantificationRequirement {
        doc /* The system shall quantify blood damage with resolution of 0.1% viability change. */
        require constraint {
            analyzer.analysisResolution <= 0.001
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The system shall automatically shut down if shear stress exceeds safe limits. */
        require constraint {
            chamber.wallShearStress <= maxShearStress
        }
    }
    
    requirement rheotraumaSystemRequirements {
        doc /* The Rheotrauma Test System shall induce controlled mechanical damage to blood samples 
             through precise shear stress application and quantify resulting cellular damage. */
        
        subject testSystem : RheotraumaTestSystem;
        
        require shearControl : ShearStressControlRequirement;
        require tempStability : TemperatureStabilityRequirement;
        require measurementAccuracy : MeasurementAccuracyRequirement;
        require damageQuantification : DamageQuantificationRequirement;
        require safety : SafetyRequirement;
    }
    
    part rheotraumaTestSystem : RheotraumaTestSystem {
        :>> maxShearStress = 500.0[SI::Pa];
        :>> operatingTemperature = 310.15[SI::K];
        :>> experimentalAccuracy = 0.02;
        
        perform runExperiment {
            :>> targetShearStress = 150.0[SI::Pa];
            :>> experimentDuration = 300.0[SI::s];
        }
    }
}
