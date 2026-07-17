package 'Gas Compressor System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def CompressionRatio :> Real;
    attribute def EfficiencyFactor :> Real;
    attribute def ControlCommand;
    
    value def GasState {
        attribute pressure : PressureValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute flowRate : VolumeFlowRateValue;
        attribute density : DensityValue;
    }
    
    value def MechanicalPower {
        attribute torque : TorqueValue;
        attribute rotationalSpeed : AngularVelocityValue;
    }
    
    port def GasFlowPort {
        attribute gasState : GasState;
    }
    
    port def ElectricalPort {
        attribute power : PowerValue;
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    port def MechanicalPort {
        attribute mechanicalPower : MechanicalPower;
    }
    
    port def ControlSignalPort {
        attribute command : ControlCommand;
        attribute feedback : PressureValue;
    }
    
    part def ElectricMotor {
        doc /* Converts electrical energy to mechanical rotational energy. */
        
        port electricalInput : ElectricalPort;
        port mechanicalOutput : MechanicalPort;
        
        attribute ratedPower : PowerValue;
        attribute efficiency : EfficiencyFactor;
        
        action def ConvertPower {
            in electricPower : PowerValue;
            out torque : TorqueValue;
            out speed : AngularVelocityValue;
        }
    }
    
    part def CompressionStage {
        doc /* Performs mechanical compression of gas through volume reduction. */
        
        port mechanicalInput : MechanicalPort;
        port gasInlet : GasFlowPort;
        port gasOutlet : GasFlowPort;
        
        attribute compressionRatio : CompressionRatio;
        attribute stageEfficiency : EfficiencyFactor;
        
        action def PerformCompression {
            in inputGas : GasState;
            in mechanicalWork : PowerValue;
            out compressedGas : GasState;
        }
    }
    
    part def IntercoolerUnit {
        doc /* Removes heat from compressed gas between stages. */
        
        port gasInlet : GasFlowPort;
        port gasOutlet : GasFlowPort;
        
        attribute coolingCapacity : PowerValue;
        attribute targetTemperature : ThermodynamicTemperatureValue;
        
        action def CoolGas {
            in hotGas : GasState;
            out cooledGas : GasState;
        }
    }
    
    part def PressureSensor {
        doc /* Measures gas pressure at specified location. */
        
        port sensingPort : GasFlowPort;
        
        attribute measurementAccuracy : Real;
        
        action def MeasurePressure {
            in gasCondition : GasState;
            out pressureReading : PressureValue;
        }
    }
    
    part def ControlValve {
        doc /* Regulates gas flow based on control signal. */
        
        port gasInlet : GasFlowPort;
        port gasOutlet : GasFlowPort;
        port controlInput : ControlSignalPort;
        
        attribute valvePosition : Real;
        
        action def RegulateFlow {
            in controlSignal : ControlCommand;
            in inletGas : GasState;
            out outletGas : GasState;
        }
    }
    
    part def SystemController {
        doc /* Manages compressor operation and maintains target pressure. */
        
        port pressureInput : ControlSignalPort;
        port motorControl : ControlSignalPort;
        port valveControl : ControlSignalPort;
        
        attribute targetPressure : PressureValue;
        attribute controlGain : Real;
        
        action def ControlOperation {
            in measuredPressure : PressureValue;
            in setPoint : PressureValue;
            out motorCommand : ControlCommand;
            out valveCommand : ControlCommand;
        }
    }
    
    part def GasCompressor {
        doc /* A gas compressor system that increases gas pressure through 
               mechanical compression, enabling gas transport and storage. 
               The system converts electrical energy to mechanical work, 
               compresses inlet gas to specified discharge pressure, and 
               maintains stable operation through feedback control. */
        
        port inletPort : GasFlowPort;
        port dischargePort : GasFlowPort;
        port powerInput : ElectricalPort;
        port controlInterface : ControlSignalPort;
        
        part motor : ElectricMotor;
        part firstStage : CompressionStage;
        part intercooler : IntercoolerUnit;
        part secondStage : CompressionStage;
        part dischargeSensor : PressureSensor;
        part dischargeValve : ControlValve;
        part controller : SystemController;
        
        attribute nominalCompressionRatio : CompressionRatio;
        attribute maxDischargePressure : PressureValue;
        attribute designFlowRate : VolumeFlowRateValue;
        attribute overallEfficiency : EfficiencyFactor;
        
        connection powerFlow connect powerInput to motor.electricalInput;
        connection mechanicalDrive1 connect motor.mechanicalOutput to firstStage.mechanicalInput;
        connection gasFlow1 connect inletPort to firstStage.gasInlet;
        connection gasFlow2 connect firstStage.gasOutlet to intercooler.gasInlet;
        connection gasFlow3 connect intercooler.gasOutlet to secondStage.gasInlet;
        connection gasFlow4 connect secondStage.gasOutlet to dischargeValve.gasInlet;
        connection gasFlow5 connect dischargeValve.gasOutlet to dischargePort;
        connection sensing connect dischargePort to dischargeSensor.sensingPort;
        connection controlFeedback connect dischargeSensor to controller.pressureInput;
        connection motorCmd connect controller.motorControl to motor;
        connection valveCmd connect controller.valveControl to dischargeValve.controlInput;
        
        perform action compressGasFlow;
    }
    
    action def CompressGasFlow {
        in inletGas : GasState;
        in targetDischargePressure : PressureValue;
        out dischargedGas : GasState;
        out operatingEfficiency : EfficiencyFactor;
    }
    
    action compressGasFlow : CompressGasFlow {
        doc /* Primary compression function: continuously compress gas from 
               inlet conditions to target discharge pressure through multi-stage 
               compression with intercooling and active pressure control. */
        
        in inletGas : GasState;
        in targetDischargePressure : PressureValue;
        out dischargedGas : GasState;
        out operatingEfficiency : EfficiencyFactor;
        
        first start;
        then merge operationCycle;
        
        action initializeSystem {
            action checkInletConditions {
                in gas : GasState = inletGas;
                out inletPressure : PressureValue;
            }
            then action setControlParameters {
                in target : PressureValue = targetDischargePressure;
                out controlSetpoint : PressureValue;
            }
        }
        then operationCycle;
        
        action monitorDischargePressure {
            in currentGas : GasState;
            out measuredPressure : PressureValue;
        }
        then decide;
        
        if monitorDischargePressure.measuredPressure < targetDischargePressure then performCompression;
        if monitorDischargePressure.measuredPressure >= targetDischargePressure then maintainPressure;
        
        action performCompression {
            first action convertElectricalPower {
                out mechanicalTorque : TorqueValue;
                out shaftSpeed : AngularVelocityValue;
            }
            then action firstStageCompression {
                in inputGas : GasState = compressGasFlow::inletGas;
                in drivePower : PowerValue;
                out stage1Gas : GasState;
            }
            then action intercoolGas {
                in hotGas : GasState = firstStageCompression.stage1Gas;
                out cooledGas : GasState;
            }
            then action secondStageCompression {
                in inputGas : GasState = intercoolGas.cooledGas;
                in drivePower : PowerValue;
                out finalGas : GasState;
            }
            then action regulateDischarge {
                in compressedGas : GasState = secondStageCompression.finalGas;
                out controlledGas : GasState;
            }
            then action updateEfficiency {
                in outputGas : GasState = regulateDischarge.controlledGas;
                out efficiencyValue : EfficiencyFactor;
            }
        }
        then operationCycle;
        
        action maintainPressure {
            action adjustValvePosition {
                in currentPressure : PressureValue = monitorDischargePressure.measuredPressure;
                out valveAdjustment : Real;
            }
            then action stabilizeFlow {
                in gas : GasState;
                out stabilizedGas : GasState;
            }
        }
        then operationCycle;
        
        action shutdownSequence {
            accept stopCommand : ControlCommand;
        }
        then done;
    }
    
    state def CompressorOperatingStates {
        entry; then idle;
        
        state idle {
            doc /* System is powered but not compressing. */
        }
        accept startCommand : ControlCommand;
        transition idle to startup;
        
        state startup {
            doc /* Motor accelerating to operating speed. */
            entry action spinUpMotor;
        }
        transition startup to running when motorAtSpeed;
        
        state running {
            doc /* Normal compression operation. */
            do action compressGasFlow;
            
            state normalOperation {
                doc /* Operating within normal parameters. */
            }
            
            state highPressureMode {
                doc /* Discharge pressure approaching maximum. */
            }
            
            transition normalOperation to highPressureMode 
                when dischargePressureHigh;
            transition highPressureMode to normalOperation 
                when dischargePressureNormal;
        }
        
        accept stopCommand : ControlCommand;
        transition running to shutdown;
        
        transition running to emergency 
            when overpressureDetected or motorOverload;
        
        state shutdown {
            doc /* Controlled shutdown sequence. */
            entry action rampDownMotor;
        }
        transition shutdown to idle when motorStopped;
        
        state emergency {
            doc /* Emergency stop due to fault condition. */
            entry action emergencyStop;
        }
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    
    requirement <'REQ-001'> primaryCompressionFunction : FunctionalRequirement {
        doc /* The gas compressor system shall increase the pressure of inlet 
               gas to a specified discharge pressure through mechanical compression. */
        
        subject compressor : GasCompressor;
        
        require constraint {
            compressor.dischargePort.gasState.pressure > 
            compressor.inletPort.gasState.pressure
        }
    }
    
    requirement <'REQ-002'> compressionRatioRequirement : PerformanceRequirement {
        doc /* The system shall achieve a minimum compression ratio of 3.5:1. */
        
        subject compressor : GasCompressor;
        
        require constraint {
            compressor.nominalCompressionRatio >= 3.5
        }
    }
    
    requirement <'REQ-003'> efficiencyRequirement : PerformanceRequirement {
        doc /* The overall system efficiency shall be at least 70%. */
        
        subject compressor : GasCompressor;
        
        require constraint {
            compressor.overallEfficiency >= 0.70
        }
    }
    
    requirement <'REQ-004'> pressureSafetyLimit : SafetyRequirement {
        doc /* The system shall not exceed maximum discharge pressure rating. */
        
        subject compressor : GasCompressor;
        
        require constraint {
            compressor.dischargePort.gasState.pressure <= 
            compressor.maxDischargePressure
        }
    }
    
    requirement <'REQ-005'> emergencyShutdown : SafetyRequirement {
        doc /* The system shall automatically shut down when discharge pressure 
               exceeds 105% of maximum rated pressure. */
        
        subject compressor : GasCompressor;
    }
    
    part industrialGasCompressor : GasCompressor {
        :>> nominalCompressionRatio = 4.0;
        :>> maxDischargePressure = 1.5e7 [Pa];
        :>> designFlowRate = 0.5 [m^3/s];
        :>> overallEfficiency = 0.75;
        
        part :>> motor {
            :>> ratedPower = 250000.0 [W];
            :>> efficiency = 0.92;
        }
        
        part :>> firstStage {
            :>> compressionRatio = 2.0;
            :>> stageEfficiency = 0.85;
        }
        
        part :>> intercooler {
            :>> coolingCapacity = 50000.0 [W];
            :>> targetTemperature = 313.15 [K];
        }
        
        part :>> secondStage {
            :>> compressionRatio = 2.0;
            :>> stageEfficiency = 0.82;
        }
        
        part :>> dischargeSensor {
            :>> measurementAccuracy = 0.005;
        }
        
        part :>> controller {
            :>> targetPressure = 1.2e7 [Pa];
            :>> controlGain = 0.8;
        }
        
        satisfy primaryCompressionFunction by compressGasFlow;
        satisfy compressionRatioRequirement by firstStage, secondStage;
        satisfy efficiencyRequirement by motor, firstStage, secondStage;
        satisfy pressureSafetyLimit by controller, dischargeValve;
        satisfy emergencyShutdown by controller;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Gas Compressor System'::*;

    part testSubject : ElectricMotor {
        exhibit state sm : CompressorOperatingStates;
    }

    action orchestrator {
        attribute testTargetDischargePressure : PressureValue;
        attribute testStopCommand : ControlCommand;
        action compressGasFlowProbe : CompressGasFlow {
            // TODO(human): unsupported input type for inletGas: GasState (type is not a primitive, enum, extracted payload def, or known value type)
            in targetDischargePressure = testTargetDischargePressure;
        }
        action triggerControlCommand send testStopCommand to compressGasFlowProbe;
        first compressGasFlowProbe;
        then triggerControlCommand;
    }
}
