package TorqueSensingUnitModel {
    private import ISQ::*;
    private import ScalarValues::*;
    private import Time::*;
    
    package Definitions {
        attribute def TorqueValue :> Torque;
        attribute def AngularVelocityValue :> AngularVelocity;
        attribute def TemperatureValue :> ThermodynamicTemperature;
        attribute def VoltageValue :> ElectricPotential;
        attribute def DigitalValue :> Integer;
        attribute def TimestampValue :> DateTime;
        
        attribute def CalibrationData {
            attribute zeroOffset : TorqueValue;
            attribute sensitivity : Real;
            attribute tempCoeff : Real;
        }
        
        item def TorqueData {
            attribute torque : TorqueValue;
            attribute angularVelocity : AngularVelocityValue;
            attribute timestamp : TimestampValue;
            attribute isValid : Boolean;
        }
        item def DiagnosticInfo {
            attribute temperature : TemperatureValue;
            attribute status : String;
        }
        item def CalibrationCommand {
            attribute commandType : String;
        }
        item def ResetCommand;
        item def SelfTestComplete;
        item def CalibrationComplete;
        item def InternalFault;
        
        port def MechanicalPort {
            in appliedTorque : TorqueValue;
            in shaftSpeed : AngularVelocityValue;
        }
        port def DataOutputPort {
            out data : TorqueData;
        }
        port def DiagnosticPort {
            in cmd : CalibrationCommand;
            in resetCmd : ResetCommand;
            out info : DiagnosticInfo;
        }
        
        action def AmplifyAndFilter {
            in rawVoltage : VoltageValue;
            out cleanVoltage : VoltageValue;
        }
        action def ConvertAnalogToDigital {
            in analogSignal : VoltageValue;
            out digitalValue : DigitalValue;
        }
        action def CalculateTorque {
            in rawDigital : DigitalValue;
            in currentTemp : TemperatureValue;
            in calData : CalibrationData;
            out finalTorque : TorqueValue;
            out finalSpeed : AngularVelocityValue;
        }
        action def PerformSelfTest {
            out passed : Boolean;
        }
        action def MeasureAndOutput {
            in torque : TorqueValue;
            in speed : AngularVelocityValue;
            out data : TorqueData;
        }
        action def DisableOutput;
        action def SignalError;
        action def PerformCalibration {
            in cmd : CalibrationCommand;
        }
        action def SenseTemperature {
            out temp : TemperatureValue;
        }
        
        part def StrainGaugeBridge {
            out rawVoltage : VoltageValue;
        }
        part def SignalConditioner {
            in rawVoltage : VoltageValue;
            out cleanVoltage : VoltageValue;
            perform action amplifyAndFilter : AmplifyAndFilter;
        }
        part def ADC {
            in analogSignal : VoltageValue;
            out digitalValue : DigitalValue;
            perform action convert : ConvertAnalogToDigital;
        }
        part def SignalProcessor {
            in rawDigital : DigitalValue;
            in currentTemp : TemperatureValue;
            attribute calibrationData : CalibrationData;
            out finalTorque : TorqueValue;
            out finalSpeed : AngularVelocityValue;
            perform action calculate : CalculateTorque;
        }
        part def TemperatureSensor {
            out currentTemp : TemperatureValue;
            perform action senseTemperature : SenseTemperature;
        }
        part def MountingFlange {
            attribute flangeDiameter : LengthValue;
            attribute boltPattern : String;
        }
        part def ShieldedCable {
            attribute length : LengthValue;
            attribute shielded : Boolean := true;
        }
        part def RuggedConnector {
            attribute connectorType : String;
        }
        
        part def TorqueSensor {
            part strainGaugeBridge : StrainGaugeBridge;
            part signalConditioner : SignalConditioner;
            part adc : ADC;
            part signalProcessor : SignalProcessor;
            part tempSensor : TemperatureSensor;
            
            connect strainGaugeBridge.rawVoltage to signalConditioner.rawVoltage;
            connect signalConditioner.cleanVoltage to adc.analogSignal;
            connect adc.digitalValue to signalProcessor.rawDigital;
            connect tempSensor.currentTemp to signalProcessor.currentTemp;
        }
        
        part def TorqueSensingUnit {
            attribute ratedTorqueLimit : TorqueValue;
            attribute maxOverloadTorque : TorqueValue;
            attribute measuredTorque : TorqueValue;
            attribute measuredSpeed : AngularVelocityValue;
            attribute isFaultDetected : Boolean := false;
            
            port mechanicalPort : MechanicalPort;
            port dataOutputPort : DataOutputPort;
            port diagnosticPort : DiagnosticPort;
            
            part torqueSensor : TorqueSensor;
            part mountingFlange : MountingFlange;
            part cable : ShieldedCable;
            part connector : RuggedConnector;
            
            perform action performSelfTest : PerformSelfTest;
            perform action measureAndOutput : MeasureAndOutput;
            perform action performCalibration : PerformCalibration;
            perform action disableOutput : DisableOutput;
            perform action signalError : SignalError;
            
            exhibit state operationalStates : OperationalStates;
        }
        
        state def OperationalStates {
            in unit : TorqueSensingUnit;
            entry; then SelfTest;
            
            state SelfTest {
                entry action doSelfTest { unit.performSelfTest; }
            }
            transition SelfTest_To_Operational
                first SelfTest
                accept SelfTestComplete
                then Operational;
            
            state Operational {
                do action doMeasure { unit.measureAndOutput; }
            }
            transition Operational_To_Calibration
                first Operational
                accept cmd : CalibrationCommand via unit.diagnosticPort
                then Calibration;
            
            state Calibration {
                do action doCalibration { unit.performCalibration; }
            }
            transition Calibration_To_Operational
                first Calibration
                accept CalibrationComplete
                then Operational;
            
            transition Operational_To_Overload
                first Operational
                if unit.measuredTorque > unit.maxOverloadTorque
                then OverloadProtection;
            
            state OverloadProtection {
                entry action doDisable { unit.disableOutput; }
            }
            transition OverloadProtection_To_Operational
                first OverloadProtection
                accept resetCmd : ResetCommand via unit.diagnosticPort
                if unit.measuredTorque <= unit.ratedTorqueLimit
                then Operational;
            
            transition Operational_To_Error
                first Operational
                accept InternalFault
                then Error;
            
            state Error {
                entry action doSignalError { unit.signalError; }
            }
            transition Error_To_SelfTest
                first Error
                accept resetCmd : ResetCommand via unit.diagnosticPort
                then SelfTest;
        }
        
        requirement def MeasurementAccuracy {
            doc /* The torque measurement accuracy shall be within 0.1 percent of full scale. */
            attribute maxErrorFraction : Real = 0.001;
            subject unit : TorqueSensingUnit;
            constraint {
                unit.measuredTorque <= unit.ratedTorqueLimit * maxErrorFraction
            }
        }
        requirement def OverloadProtectionRequirement {
            doc /* The unit shall disable output when torque exceeds 120 percent of rated torque. */
            subject unit : TorqueSensingUnit;
            constraint {
                unit.maxOverloadTorque == unit.ratedTorqueLimit * 1.2
            }
        }
        requirement def CalibrationCapability {
            doc /* The unit shall support zero and span calibration via diagnostic port. */
            subject unit : TorqueSensingUnit;
        }
        requirement def RealTimeDataOutput {
            doc /* The unit shall output torque, angular velocity, timestamp, and status continuously. */
            subject unit : TorqueSensingUnit;
        }
    }
    
    package Usages {
        private import Definitions::*;
        part torqueSensingUnit1 : TorqueSensingUnit {
            attribute ratedTorqueLimit := 500 [N*m];
            attribute maxOverloadTorque := 600 [N*m];
        }
    }
}
