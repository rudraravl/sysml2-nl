package MAPSensorSystem {
    public import ScalarValues::*;
    public import ISQ::*;
    public import SI::*;
    
    package Definitions {
        public import AttributeDefinitions::*;
        public import PortDefinitions::*;
        public import ItemDefinitions::*;
        public import ActionDefinitions::*;
        public import StateDefinitions::*;
        public import RequirementDefinitions::*;
        public import PartDefinitions::*;
        
        package AttributeDefinitions {
            attribute def StartSignal;
            attribute def OnSignal;
            attribute def OffSignal;
            attribute def FaultSignal;
            attribute def FaultCleared;
            enum def StatusCode {
                normal;
                fault;
                selfTest;
            }
            attribute def MAPDataPacket {
                attribute pressure :> ISQ::pressure;
                attribute temperature :> ISQ::temperature;
                attribute status : StatusCode;
            }
        }
        
        package PortDefinitions {
            port def PneumaticPort {
                attribute pressure :> ISQ::pressure;
            }
            port def ElectricalPowerPort {
                attribute voltage :> ISQ::electricPotential;
            }
            port def AnalogSignalPort {
                attribute voltage :> ISQ::electricPotential;
            }
            port def DigitalSignalPort {
                attribute data : Integer;
            }
            port def MAPDataPort {
                attribute packet : MAPDataPacket;
            }
        }
        
        package ItemDefinitions {
            item def Air;
        }
        
        package ActionDefinitions {
            action def MeasureDeformation;
            action def AmplifySignal;
            action def CompensateTemperature;
            action def FilterNoise;
            action def ConvertAD;
            action def ProcessData;
            action def PerformSelfTest;
            action def PerformDiagnostics;
            action def TransmitData;
            action def CalculateEngineLoad;
            action def AdjustFuelInjection;
            action def AdjustIgnitionTiming;
            action def NormalSensorOperation {
                action measureDeformation : MeasureDeformation;
                action processData : ProcessData;
                action transmitData : TransmitData;
                action performDiagnostics : PerformDiagnostics;
            }
            action def NormalECUOperation {
                action calculateEngineLoad : CalculateEngineLoad;
                action adjustFuelInjection : AdjustFuelInjection;
                action adjustIgnitionTiming : AdjustIgnitionTiming;
            }
        }
        
        package StateDefinitions {
            state def MAPSensorStates;
            state def ECUStates;
        }
        
        package PartDefinitions {
            part def IntakeManifold {
                attribute pressure :> ISQ::pressure;
                port airPort : PneumaticPort;
                ref item air : Air;
            }
            
            part def MAPSensor {
                attribute mass :> ISQ::mass;
                port pneumaticPort : PneumaticPort;
                port powerPort : ElectricalPowerPort;
                port dataOutPort : MAPDataPort;
                
                part piezoelectricElement {
                    port mechIn : PneumaticPort;
                    port defOut : AnalogSignalPort;
                }
                
                part strainGaugeBridge {
                    port sigIn : AnalogSignalPort;
                    port sigOut : AnalogSignalPort;
                    perform action measureDeformation : MeasureDeformation;
                }
                
                part signalAmplifier {
                    port sigIn : AnalogSignalPort;
                    port sigOut : AnalogSignalPort;
                    perform action amplifySignal : AmplifySignal;
                }
                
                part temperatureSensor {
                    port tempOut : AnalogSignalPort;
                }
                
                part temperatureCompensator {
                    port sigIn : AnalogSignalPort;
                    port tempIn : AnalogSignalPort;
                    port sigOut : AnalogSignalPort;
                    perform action compensateTemperature : CompensateTemperature;
                }
                
                part lowPassFilter {
                    port sigIn : AnalogSignalPort;
                    port sigOut : AnalogSignalPort;
                    perform action filterNoise : FilterNoise;
                }
                
                part adc {
                    port analogIn : AnalogSignalPort;
                    port digitalOut : DigitalSignalPort;
                    perform action convertAD : ConvertAD;
                }
                
                part microcontroller {
                    port digitalIn : DigitalSignalPort;
                    port tempIn : AnalogSignalPort;
                    port dataOut : MAPDataPort;
                    perform action processData : ProcessData;
                    perform action performSelfTest : PerformSelfTest;
                    perform action performDiagnostics : PerformDiagnostics;
                    perform action transmitData : TransmitData;
                }
                
                connect pneumaticPort to piezoelectricElement.mechIn;
                connect piezoelectricElement.defOut to strainGaugeBridge.sigIn;
                connect strainGaugeBridge.sigOut to signalAmplifier.sigIn;
                connect signalAmplifier.sigOut to temperatureCompensator.sigIn;
                connect temperatureSensor.tempOut to temperatureCompensator.tempIn;
                connect temperatureCompensator.sigOut to lowPassFilter.sigIn;
                connect lowPassFilter.sigOut to adc.analogIn;
                connect adc.digitalOut to microcontroller.digitalIn;
                connect temperatureSensor.tempOut to microcontroller.tempIn;
                connect microcontroller.dataOut to dataOutPort;
            }
            
            part def ECU {
                attribute engineLoad : Real;
                port mapDataPort : MAPDataPort;
                port powerOutPort : ElectricalPowerPort;
            }
        }
        
        package RequirementDefinitions {
            requirement def PressureRangeRequirement {
                doc /* The sensor shall measure absolute pressure from 10 kPa to 250 kPa. */
                attribute minPressure :> ISQ::pressure = 10000;
                attribute maxPressure :> ISQ::pressure = 250000;
            }
            requirement def TemperatureRangeRequirement {
                doc /* The sensor must operate accurately from -40C to +150C. */
                attribute minTemp :> ISQ::temperature = 233.15;
                attribute maxTemp :> ISQ::temperature = 423.15;
            }
            requirement def ResponseTimeRequirement {
                doc /* The sensor must have a fast response time of less than 10 ms. */
                attribute maxResponseTime :> ISQ::time = 0.01;
            }
        }
    }
    
    public import Definitions::*;
    
    part mapSensorSystem {
        part intakeManifold : IntakeManifold;
        part mapSensor : MAPSensor;
        part ecu : ECU;
        
        action normalSensorOperation : NormalSensorOperation;
        action normalECUOperation : NormalECUOperation;
        action performSelfTest : PerformSelfTest;
        
        connect intakeManifold.airPort to mapSensor.pneumaticPort;
        connect ecu.powerOutPort to mapSensor.powerPort;
        connect mapSensor.dataOutPort to ecu.mapDataPort;
        
        bind intakeManifold.pressure = mapSensor.pneumaticPort.pressure;
        
        exhibit state mapSensorStates : MAPSensorStates parallel {
            state operationalStates {
                entry; then off;
                state off;
                accept StartSignal
                    do performSelfTest
                    then starting;
                state starting;
                accept OnSignal
                    then normal;
                state normal {
                    do normalSensorOperation;
                }
                accept FaultSignal
                    do send new FaultSignal() to ecu
                    then fault;
                accept OffSignal
                    then off;
                state fault;
                accept FaultCleared
                    then normal;
            }
        }
        
        exhibit state ecuStates : ECUStates parallel {
            state ecuOperationalStates {
                entry; then standby;
                state standby;
                accept StartSignal
                    then active;
                state active {
                    do normalECUOperation;
                }
                accept OffSignal
                    then standby;
            }
        }
    }
}
