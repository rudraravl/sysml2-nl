package 'DynamicTorqueSensingUnit' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import UnitsAndScales::*;
    private import Quantities::*;
    
    doc /* This package defines a complete dynamic torque sensing unit that measures
     * torque in rotating mechanical systems using strain gauge technology with
     * real-time signal processing and calibration capabilities.
     */
    
    attribute def CalibrationData {
        attribute zeroOffset : Real;
        attribute sensitivityFactor : Real;
        attribute temperatureCoefficient : Real;
        attribute calibrationDate : String;
    }
    
    attribute def SensorAccuracy {
        attribute percentFullScale : Real;
        attribute resolution : Real;
    }
    
    item def TorqueMeasurement {
        attribute torqueValue : Real;
        attribute angularVelocity : Real;
        attribute timestamp : Real;
        attribute validData : Boolean;
    }
    
    port def MechanicalInputPort {
        in item appliedTorque : Real;
        in item rotationalSpeed : Real;
    }
    
    port def TorqueOutputPort {
        out item measurement : TorqueMeasurement;
    }
    
    port def PowerPort {
        in item supplyVoltage : Real;
    }
    
    port def DiagnosticPort {
        out item temperature : Real;
        out item status : SensorStatus;
        in item calibrationCmd : CalibrationCommand;
    }
    
    enum def SensorStatus {
        enum Initializing;
        enum Operational;
        enum Calibrating;
        enum Error;
        enum Overload;
    }
    
    enum def CalibrationCommand {
        enum PerformZeroCalibration;
        enum PerformSpanCalibration;
        enum ResetToFactory;
        enum NoCommand;
    }
    
    part def StrainGaugeBridge {
        attribute bridgeResistance : Real;
        attribute gaugeFactor : Real;
        attribute excitationVoltage : Real;
        
        port mechanicalIn : MechanicalInputPort;
        port signalOut {
            out item outputVoltage : Real;
        }
        
        action convertTorqueToVoltage {
            in torque : Real;
            in excitation : Real;
            out voltage : Real;
        }
    }
    
    part def SignalConditioner {
        attribute gain : Real;
        attribute bandwidth : Real;
        
        port analogIn {
            in item rawSignal : Real;
        }
        
        port analogOut {
            out item conditionedSignal : Real;
        }
        
        action amplifyAndFilter {
            in inputSignal : Real;
            in amplifierGain : Real;
            out outputSignal : Real;
        }
    }
    
    part def AnalogDigitalConverter {
        attribute resolution : Integer;
        attribute samplingRate : Real;
        
        port analogIn {
            in item analogSignal : Real;
        }
        
        port digitalOut {
            out item digitalValue : Integer;
        }
        
        action convertSignal {
            in analog : Real;
            out digital : Integer;
        }
    }
    
    part def SignalProcessor {
        attribute filterCutoff : Real;
        attribute calibration : CalibrationData;
        
        port dataIn {
            in item rawData : Integer;
        }
        
        port dataOut {
            out item processedTorque : Real;
        }
        
        action processData {
            in rawValue : Integer;
            in calibrationData : CalibrationData;
            out torque : Real;
            
            action applyCalibration {
                in digitalInput : Integer;
                in offset : Real;
                in sensitivity : Real;
                out calibratedValue : Real;
            }
            
            then action filterNoise {
                in calibratedInput : Real;
                out filteredValue : Real;
            }
            
            then action convertToTorque {
                in processedValue : Real;
                out finalTorque : Real;
            }
        }
    }
    
    part def TemperatureSensor {
        port tempOut {
            out item temperature : Real;
        }
        
        action measureTemperature {
            out temp : Real;
        }
    }
    
    part def DynamicTorqueSensor {
        doc /* Dynamic torque sensor that measures torque in rotating shafts
         * using strain gauge bridge technology with integrated signal processing.
         */
        
        attribute modelNumber : String;
        attribute ratedTorque : Real;
        attribute maxSpeed : Real;
        attribute accuracy : SensorAccuracy;
        
        port mechanicalInterface : MechanicalInputPort;
        port torqueOutput : TorqueOutputPort;
        port powerSupply : PowerPort;
        port diagnostics : DiagnosticPort;
        
        part strainGauge : StrainGaugeBridge {
            attribute :>> bridgeResistance = 350.0;
            attribute :>> gaugeFactor = 2.1;
        }
        
        part conditioner : SignalConditioner {
            attribute :>> gain = 1000.0;
        }
        
        part adc : AnalogDigitalConverter {
            attribute :>> resolution = 24;
        }
        
        part processor : SignalProcessor {
            part :>> calibration {
                attribute :>> sensitivityFactor = 1.0;
                attribute :>> temperatureCoefficient = 0.0001;
            }
        }
        
        part tempSensor : TemperatureSensor;
        
        part controller {
            attribute currentStatus : SensorStatus;
        }
        
        connect mechanicalInterface to strainGauge.mechanicalIn;
        connect strainGauge.signalOut to conditioner.analogIn;
        connect conditioner.analogOut to adc.analogIn;
        connect adc.digitalOut to processor.dataIn;
        connect processor.dataOut to torqueOutput;
        connect tempSensor.tempOut to diagnostics;
        
        action sensorControl {
            first start;
            then state init {
                do action selfTest {
                    action checkPower;
                    then action checkBridge;
                    then action verifyADC;
                }
            }
            
            accept at init then operational;
            
            then state operational {
                do action measure {
                    action readBridge;
                    then action conditionSignal;
                    then action digitize;
                    then action process;
                    then action outputMeasurement;
                }
            }
            
            accept at operational then calibrating;
            accept at operational then overload;
            
            then state calibrating {
                do action calibrate {
                    action zeroCalibration {
                        out offset : Real;
                    }
                    then action spanCalibration {
                        in reference : Real;
                        out sensitivity : Real;
                    }
                    then action updateCalibration {
                        in offset : Real;
                        in sensitivity : Real;
                        out newCalibration : CalibrationData;
                    }
                }
            }
            
            accept at calibrating then operational;
            
            then state overload {
                do action protect {
                    action disableOutput;
                    then action waitRecovery;
                }
            }
            
            accept at overload then operational;
            
            then state error {
                do action handleError {
                    action logError;
                    then action attemptRecovery;
                }
            }
            
            accept at error then init;
        }
    }
    
    part def SensingUnit {
        doc /* Complete sensing unit assembly integrating the dynamic torque sensor
         * with mounting hardware and interface connections for torque measurement.
         */
        
        part sensor : DynamicTorqueSensor {
            attribute :>> modelNumber = "DTS-5000";
        }
        
        part mountingHardware {
            attribute flangeType : String;
            attribute boltPattern : String;
        }
        
        part cableAssembly {
            attribute cableLength : Real;
            attribute shielding : String;
            attribute connectorType : String;
        }
        
        port mechanicalInput : MechanicalInputPort;
        port torqueDataOutput : TorqueOutputPort;
        port powerInput : PowerPort;
        port diagnosticInterface : DiagnosticPort;
        
        attribute maxTorque : Real;
        attribute maxSpeed : Real;
        attribute supplyVoltage : Real;
        attribute samplingRate : Real;
        attribute minResolution : Real;
        
        connect mechanicalInput to sensor.mechanicalInterface;
        connect sensor.torqueOutput to torqueDataOutput;
        connect powerInput to sensor.powerSupply;
        connect sensor.diagnostics to diagnosticInterface;
        
        requirement sensingRequirements {
            doc /* Requirements for the dynamic torque sensing unit */
            
            requirement measurementAccuracy {
                doc /* The sensor shall measure torque with accuracy better than 0.1% of full scale */
                subject unit : SensingUnit;
                require unit.sensor.accuracy.percentFullScale <= 0.1;
            }
            
            requirement samplingPerformance {
                doc /* The sensor shall provide torque readings at minimum 1000 Hz sampling rate */
                subject unit : SensingUnit;
                require unit.sensor.adc.samplingRate >= 1000.0;
            }
            
            requirement operationalRange {
                doc /* The sensor shall operate across the specified torque and speed range */
                subject unit : SensingUnit;
                require unit.sensor.ratedTorque == unit.maxTorque;
                require unit.sensor.maxSpeed == unit.maxSpeed;
            }
            
            requirement temperatureCompensation {
                doc /* The sensor shall compensate for temperature variations */
                subject unit : SensingUnit;
                require unit.sensor.processor.calibration.temperatureCoefficient != 0.0;
            }
            
            requirement continuousOperation {
                doc /* The sensor shall provide continuous real-time measurements */
                subject unit : SensingUnit;
                require unit.sensor.controller.currentStatus == SensorStatus::Operational;
            }
        }
    }
    
    part sensingUnitInstance : SensingUnit {
        attribute :>> maxTorque = 500.0;
        attribute :>> maxSpeed = 10000.0;
        attribute :>> supplyVoltage = 24.0;
        attribute :>> samplingRate = 2000.0;
        attribute :>> minResolution = 0.01;
        
        part :>> sensor {
            attribute :>> ratedTorque = 500.0;
            attribute :>> maxSpeed = 10000.0;
            
            part :>> accuracy {
                attribute :>> percentFullScale = 0.1;
                attribute :>> resolution = 0.01;
            }
            
            part :>> strainGauge {
                attribute :>> excitationVoltage = 10.0;
            }
            
            part :>> conditioner {
                attribute :>> bandwidth = 1000.0;
            }
            
            part :>> adc {
                attribute :>> samplingRate = 2000.0;
            }
            
            part :>> processor {
                attribute :>> filterCutoff = 500.0;
                
                part :>> calibration {
                    attribute :>> zeroOffset = 0.0;
                    attribute :>> calibrationDate = "2025-01-15";
                }
            }
        }
        
        part :>> mountingHardware {
            attribute :>> flangeType = "SAE-J620";
            attribute :>> boltPattern = "4-bolt-square";
        }
        
        part :>> cableAssembly {
            attribute :>> cableLength = 5.0;
            attribute :>> shielding = "braided-shield";
            attribute :>> connectorType = "M12-8pin";
        }
    }
}
