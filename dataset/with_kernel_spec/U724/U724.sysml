package DigitalInclinometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        item def AccelerationVector {
            attribute x :> ISQ::acceleration;
            attribute y :> ISQ::acceleration;
            attribute z :> ISQ::acceleration;
        }
        item def TiltMeasurement {
            attribute pitch :> ISQ::plane_angle;
            attribute roll :> ISQ::plane_angle;
            attribute isValid : Boolean;
            attribute confidence : Real;
        }
        item def PowerSignal {
            attribute voltage :> ISQ::electric_voltage;
            attribute current :> ISQ::electric_current;
        }
        item def CalibrationData {
            attribute xOffset :> ISQ::acceleration;
            attribute yOffset :> ISQ::acceleration;
            attribute zOffset :> ISQ::acceleration;
        }
        
        attribute def PowerOnSignal;
        attribute def PowerOffSignal;
        attribute def StartCalibrationSignal;
        attribute def EndCalibrationSignal;
        attribute def ResetSignal;
        attribute def FaultSignal;
        attribute def SelfTestPassed;
        attribute def SelfTestFailed;
        
        port def AccelerometerOutPort { out acceleration : AccelerationVector; }
        port def ProcessorAccInPort { in acceleration : AccelerationVector; }
        port def ProcessorDisplayOutPort { out measurement : TiltMeasurement; }
        port def DisplayInPort { in measurement : TiltMeasurement; }
        port def ProcessorDataOutPort { out measurement : TiltMeasurement; }
        port def PowerInPort { in power : PowerSignal; }
        port def PowerOutPort { out power : PowerSignal; }
        port def CommandPort { in command : String; }
        
        action def MeasureAcceleration { out acceleration : AccelerationVector; }
        action def ProcessAcceleration {
            in acceleration : AccelerationVector;
            in calibration : CalibrationData;
            out measurement : TiltMeasurement;
        }
        action def UpdateDisplay { in measurement : TiltMeasurement; }
        action def RegulatePower {
            in inputPower : PowerSignal;
            out outputPower : PowerSignal;
        }
        action def PerformSelfTest { out testPassed : Boolean; }
        action def PerformCalibration { out calibration : CalibrationData; }
        
        state def InclinometerStates;
        
        part def DigitalInclinometer {
            attribute mass :> ISQ::mass;
            attribute updateRate :> ISQ::frequency;
            attribute operatingVoltage :> ISQ::electric_voltage;
            port cmdPort : CommandPort;
            port dataOutPort : ProcessorDataOutPort;
            port extPowerInPort : PowerInPort;
            perform action measureTilt : MeasureAcceleration;
            perform action processTilt : ProcessAcceleration;
            perform action displayTilt : UpdateDisplay;
            perform action selfTest : PerformSelfTest;
            perform action calibrate : PerformCalibration;
            exhibit state operationalStates : InclinometerStates;
        }
        part def MEMSAccelerometer {
            attribute measurementRange :> ISQ::acceleration;
            attribute resolution :> ISQ::acceleration;
            port accOutPort : AccelerometerOutPort;
            port pwrInPort : PowerInPort;
            perform action measure : MeasureAcceleration;
        }
        part def SignalProcessor {
            attribute samplingRate :> ISQ::frequency;
            attribute filterCutoff :> ISQ::frequency;
            attribute calibrationData : CalibrationData;
            port accInPort : ProcessorAccInPort;
            port dispOutPort : ProcessorDisplayOutPort;
            port dataOutPort : ProcessorDataOutPort;
            port pwrInPort : PowerInPort;
            port cmdPort : CommandPort;
            perform action process : ProcessAcceleration;
        }
        part def DisplayController {
            attribute refreshRate :> ISQ::frequency;
            port dispInPort : DisplayInPort;
            port pwrInPort : PowerInPort;
            perform action update : UpdateDisplay;
        }
        part def PowerRegulator {
            attribute outputVoltage :> ISQ::electric_voltage;
            attribute efficiency : Real;
            port extInPort : PowerInPort;
            port accOutPort : PowerOutPort;
            port procOutPort : PowerOutPort;
            port dispOutPort : PowerOutPort;
            perform action regulate : RegulatePower;
        }
        part def ExternalPowerSource {
            port pwrOutPort : PowerOutPort;
        }
        
        requirement def AccuracyRequirement {
            doc /* The system shall measure pitch and roll angles with an accuracy of ±0.1 degrees. */
            attribute maxError :> ISQ::plane_angle;
        }
        requirement def UpdateRateRequirement {
            doc /* The system shall update tilt measurements at a minimum rate of 10 Hz. */
            attribute minRate :> ISQ::frequency;
        }
        requirement def PowerStabilityRequirement {
            doc /* The power regulator shall provide stable 3.3V ±5% to all components. */
            attribute nominalVoltage :> ISQ::electric_voltage;
            attribute tolerance : Real;
        }
        requirement def CalibrationRequirement {
            doc /* The system shall support field calibration to correct mounting offsets up to ±5 degrees. */
            attribute maxOffset :> ISQ::plane_angle;
        }
        requirement def SelfTestRequirement {
            doc /* The system shall perform a self-test on startup to verify functionality. */
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part inclinometer : DigitalInclinometer {
            part accelerometer : MEMSAccelerometer;
            part processor : SignalProcessor;
            part display : DisplayController;
            part regulator : PowerRegulator;
            part extPower : ExternalPowerSource;
            
            flow of PowerSignal from extPower.pwrOutPort.power to regulator.extInPort.power;
            flow of PowerSignal from regulator.accOutPort.power to accelerometer.pwrInPort.power;
            flow of PowerSignal from regulator.procOutPort.power to processor.pwrInPort.power;
            flow of PowerSignal from regulator.dispOutPort.power to display.pwrInPort.power;
            flow of AccelerationVector from accelerometer.accOutPort.acceleration to processor.accInPort.acceleration;
            flow of TiltMeasurement from processor.dispOutPort.measurement to display.dispInPort.measurement;
            flow of TiltMeasurement from processor.dataOutPort.measurement to inclinometer.dataOutPort.measurement;
            
            exhibit state operationalStates : InclinometerStates {
                entry; then poweredOff;
                
                state poweredOff;
                accept PowerOnSignal then initializing;
                
                state initializing {
                    entry selfTest;
                    accept SelfTestPassed then operational;
                    accept SelfTestFailed then error;
                }
                
                state operational {
                    do measureTilt;
                    do processTilt;
                    do displayTilt;
                }
                accept StartCalibrationSignal then calibration;
                accept PowerOffSignal then poweredOff;
                accept FaultSignal then error;
                accept ResetSignal then initializing;
                
                state calibration {
                    entry calibrate;
                    do measureTilt;
                    do processTilt;
                }
                accept EndCalibrationSignal then operational;
                accept PowerOffSignal then poweredOff;
                accept FaultSignal then error;
                
                state error;
                accept ResetSignal then initializing;
                accept PowerOffSignal then poweredOff;
            }
        }
        
        requirement accuracyReq : AccuracyRequirement {
            maxError = 0.1 [deg];
        }
        requirement updateRateReq : UpdateRateRequirement {
            minRate = 10 [Hz];
        }
        requirement powerStabilityReq : PowerStabilityRequirement {
            nominalVoltage = 3.3 [V];
            tolerance = 0.05;
        }
        requirement calibrationReq : CalibrationRequirement {
            maxOffset = 5.0 [deg];
        }
        requirement selfTestReq : SelfTestRequirement;
        
        assert constraint {
            inclinometer.updateRate >= updateRateReq.minRate
        }
        assert constraint {
            inclinometer.regulator.outputVoltage >= powerStabilityReq.nominalVoltage * (1 - powerStabilityReq.tolerance) and
            inclinometer.regulator.outputVoltage <= powerStabilityReq.nominalVoltage * (1 + powerStabilityReq.tolerance)
        }
    }
}
