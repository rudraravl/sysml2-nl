package VSG_Model {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SI::*;

    package Definitions {
        package ItemDefinitions {
            item def DriveCommand {
                attribute voltage :> ISQ::electricPotential;
                attribute frequency :> ISQ::frequency;
            }
            item def ForceItem {
                attribute value :> ISQ::force;
            }
            item def DisplacementItem {
                attribute value :> ISQ::length;
            }
            item def CapacitanceChange {
                attribute value :> ISQ::capacitance;
            }
            item def PickoffSignal {
                attribute amplitude :> ISQ::electricPotential;
                attribute frequency :> ISQ::frequency;
            }
            item def SenseSignal {
                attribute amplitude :> ISQ::electricPotential;
            }
            item def ProcessedSignal {
                attribute voltage :> ISQ::electricPotential;
            }
            item def AngularRateOutput {
                attribute rate :> ISQ::angularVelocity;
            }
            item def TemperatureReading {
                attribute temp :> ISQ::temperature;
            }
            item def CalibrationData {
                attribute scaleFactor : ScalarValues::Real;
                attribute bias :> ISQ::angularVelocity;
            }
            item def ElectricalPower {
                attribute value :> ISQ::power;
            }
        }

        package PortDefinitions {
            private import ItemDefinitions::*;
            port def DriveElectricalOutPort { out item driveCmd : DriveCommand; }
            port def DriveElectricalInPort { in item driveCmd : DriveCommand; }
            port def ForceOutPort { out item force : ForceItem; }
            port def ForceInPort { in item force : ForceItem; }
            port def DisplacementOutPort { out item disp : DisplacementItem; }
            port def DisplacementInPort { in item disp : DisplacementItem; }
            port def CapacitanceOutPort { out item capChange : CapacitanceChange; }
            port def CapacitanceInPort { in item capChange : CapacitanceChange; }
            port def PickoffOutPort { out item pickoff : PickoffSignal; }
            port def PickoffInPort { in item pickoff : PickoffSignal; }
            port def SignalOutPort { out item signal : ProcessedSignal; }
            port def SignalInPort { in item signal : ProcessedSignal; }
            port def AngularRateOutPort { out item rateOut : AngularRateOutput; }
            port def TemperatureOutPort { out item tempReading : TemperatureReading; }
            port def TemperatureInPort { in item tempReading : TemperatureReading; }
            port def PowerPort { in item power : ElectricalPower; }
        }

        package SignalDefinitions {
            attribute def PowerOnSignal;
            attribute def SelfTestCompleteSignal;
            attribute def WarmUpCompleteSignal;
            attribute def CalibrationCommandSignal;
            attribute def CalibrationCompleteSignal;
            attribute def FaultDetectedSignal;
            attribute def FaultClearedSignal;
        }

        package ActionDefinitions {
            private import ItemDefinitions::*;

            action def MaintainDriveOscillation {
                in targetFreq :> ISQ::frequency;
                in feedback : PickoffSignal;
                out driveCmd : DriveCommand;
            }
            action def SenseCoriolisMotion {
                in capChange : CapacitanceChange;
                out senseSignal : SenseSignal;
            }
            action def ProcessSignal {
                in signal : SenseSignal;
                out processed : ProcessedSignal;
            }
            action def CompensateTemperature {
                in rawRate :> ISQ::angularVelocity;
                in temperature :> ISQ::temperature;
                out compensatedRate :> ISQ::angularVelocity;
            }
            action def ApplyCalibration {
                in rawRate :> ISQ::angularVelocity;
                in calData : CalibrationData;
                out calibratedRate :> ISQ::angularVelocity;
            }
            action def SelfTest {
                out testPassed : Boolean;
            }
        }

        package PartDefinitions {
            private import PortDefinitions::*;
            private import ItemDefinitions::*;
            private import ActionDefinitions::*;

            part def ResonantMass {
                attribute mass :> ISQ::mass;
                attribute resonantFrequency :> ISQ::frequency;
                attribute qualityFactor : ScalarValues::Real;
                port driveForce : ForceInPort;
                port senseMotion : DisplacementOutPort;
            }
            part def DriveElectrodes {
                port electricalIn : DriveElectricalInPort;
                port electrostaticOut : ForceOutPort;
            }
            part def SenseElectrodes {
                port motionIn : DisplacementInPort;
                port capacitanceOut : CapacitanceOutPort;
                port pickoffOut : PickoffOutPort;
            }
            part def DriveLoopElectronics {
                attribute targetAmplitude :> ISQ::electricPotential;
                port senseIn : PickoffInPort;
                port driveOut : DriveElectricalOutPort;
                port powerIn : PowerPort;
            }
            part def SenseElectronics {
                port capacitanceIn : CapacitanceInPort;
                port signalOut : SignalOutPort;
                port powerIn : PowerPort;
            }
            part def DSP {
                attribute calData : CalibrationData;
                port signalIn : SignalInPort;
                port temperatureIn : TemperatureInPort;
                port angularRateOut : AngularRateOutPort;
                port powerIn : PowerPort;
            }
            part def TemperatureSensor {
                port temperatureOut : TemperatureOutPort;
                port powerIn : PowerPort;
            }
            part def VacuumPackage {
                attribute vacuumLevel :> ISQ::pressure;
            }
            part def Gyroscope {
                attribute resonantFrequency :> ISQ::frequency;
                port powerIn : PowerPort;
                port angularRateOut : AngularRateOutPort;

                part mass : ResonantMass;
                part driveElectrodes : DriveElectrodes;
                part senseElectrodes : SenseElectrodes;
                part driveLoop : DriveLoopElectronics;
                part senseElectronics : SenseElectronics;
                part dsp : DSP;
                part tempSensor : TemperatureSensor;
                part vacuumPkg : VacuumPackage;

                connect powerIn to driveLoop.powerIn;
                connect powerIn to senseElectronics.powerIn;
                connect powerIn to dsp.powerIn;
                connect powerIn to tempSensor.powerIn;

                connect driveLoop.driveOut to driveElectrodes.electricalIn;
                connect driveElectrodes.electrostaticOut to mass.driveForce;
                connect mass.senseMotion to senseElectrodes.motionIn;
                connect senseElectrodes.capacitanceOut to senseElectronics.capacitanceIn;
                connect senseElectrodes.pickoffOut to driveLoop.senseIn;
                connect senseElectronics.signalOut to dsp.signalIn;
                connect tempSensor.temperatureOut to dsp.temperatureIn;
                connect dsp.angularRateOut to angularRateOut;

                perform action maintainDriveOscillation : MaintainDriveOscillation;
                perform action senseCoriolisMotion : SenseCoriolisMotion;
                perform action processSignal : ProcessSignal;
                perform action compensateTemperature : CompensateTemperature;
                perform action applyCalibration : ApplyCalibration;
                perform action selfTest : SelfTest;
            }
        }

        package StateDefinitions {
            private import SignalDefinitions::*;
            private import PartDefinitions::*;
            private import ActionDefinitions::*;

            state def GyroscopeStates {
                entry; then off;
                state off;
                accept PowerOnSignal
                    then initializing;
                state initializing {
                    do selfTest;
                    accept SelfTestCompleteSignal
                        then warmUp;
                }
                state warmUp {
                    do maintainDriveOscillation;
                    accept WarmUpCompleteSignal
                        then normal;
                }
                state normal {
                    do senseCoriolisMotion;
                    do processSignal;
                    do compensateTemperature;
                    do applyCalibration;
                    accept CalibrationCommandSignal
                        then calibration;
                    accept FaultDetectedSignal
                        then fault;
                }
                state calibration {
                    accept CalibrationCompleteSignal
                        then normal;
                }
                state fault {
                    accept FaultClearedSignal
                        then off;
                }
            }
        }

        package RequirementDefinitions {
            requirement def AngularRateAccuracy {
                doc /* The gyroscope shall measure angular rate with an accuracy of ±0.1 deg/s over the full temperature range. */
                attribute accuracy :> ISQ::angularVelocity;
                assert constraint { accuracy <= 0.1 [deg/s] }
            }
            requirement def WarmUpTime {
                doc /* The gyroscope shall achieve stable operation within 1 second after power-on. */
                attribute maxWarmUpTime :> ISQ::duration;
                assert constraint { maxWarmUpTime <= 1 [s] }
            }
            requirement def ScaleFactorStability {
                doc /* The scale factor shall not vary more than 0.5% over temperature. */
                attribute scaleFactorVariation : ScalarValues::Real;
                assert constraint { scaleFactorVariation <= 0.005 }
            }
            requirement def BiasStability {
                doc /* The bias stability shall be less than 10 deg/h. */
                attribute biasStability :> ISQ::angularVelocity;
                assert constraint { biasStability <= 10 [deg/h] }
            }
        }
    }

    package Usages {
        private import Definitions::*;
        private import Definitions::StateDefinitions::*;

        part gyro1 : Gyroscope {
            exhibit state gyroStates : GyroscopeStates;
        }
    }
}
