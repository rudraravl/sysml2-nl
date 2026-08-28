package HPGeDetectorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        attribute def TemperatureValue :> ISQ::temperature;
        attribute def VoltageValue :> ISQ::electricPotential;
        attribute def EnergyValue :> ISQ::energy;
        attribute def ChargeValue :> ISQ::electricCharge;
        attribute def TimeValue :> ISQ::time;

        item def RadiationParticle {
            attribute particleEnergy : EnergyValue;
            attribute particleType : String;
        }
        item def GammaRay :> RadiationParticle;
        item def ChargePulse {
            attribute charge : ChargeValue;
        }
        item def ElectricalPulse {
            attribute amplitude : VoltageValue;
            attribute duration : TimeValue;
        }
        item def ShapedPulse {
            attribute peakAmplitude : VoltageValue;
            attribute duration : TimeValue;
        }
        item def DigitalEvent {
            attribute eventId : Integer;
            attribute measuredEnergy : EnergyValue;
            attribute timestamp : TimeValue;
        }

        attribute def InitSignal;
        attribute def StartAcquisitionSignal;
        attribute def StopAcquisitionSignal;
        attribute def ShutdownSignal;
        attribute def MaintenanceSignal;
        attribute def ReadySignal;
        attribute def ResumeFromMaintenanceSignal;
        attribute def ShutdownCompleteSignal;

        port def RadiationInPort {
            in item radiation : RadiationParticle;
        }
        port def ChargePulseOutPort {
            out item chargePulse : ChargePulse;
        }
        port def ChargePulseInPort {
            in item chargePulse : ChargePulse;
        }
        port def ElectricalPulseOutPort {
            out item pulse : ElectricalPulse;
        }
        port def ElectricalPulseInPort {
            in item pulse : ElectricalPulse;
        }
        port def ShapedPulseOutPort {
            out item shapedPulse : ShapedPulse;
        }
        port def ShapedPulseInPort {
            in item shapedPulse : ShapedPulse;
        }
        port def DigitalEventOutPort {
            out item digitalEvent : DigitalEvent;
        }
        port def DigitalEventInPort {
            in item digitalEvent : DigitalEvent;
        }

        action def DetectRadiation;
        action def AmplifyCharge;
        action def ShapePulse;
        action def AnalyzePulseHeight;
        action def AcquireEvent;
        action def RampUpHV;
        action def RampDownHV;
        action def CoolSensor;
        action def WarmSensor;
        action def AcquireData;
        action def InitializeSystem;
        action def ShutdownSystem;

        state def SystemStates;

        part def HPGESensorCrystal {
            attribute operatingTemperature : TemperatureValue;
            attribute appliedHV : VoltageValue;
            port radiationIn : RadiationInPort;
            port chargeOut : ChargePulseOutPort;
            perform action detectRadiation : DetectRadiation;
        }
        part def TemperatureController {
            attribute targetTemp : TemperatureValue;
            attribute currentTemp : TemperatureValue;
            perform action coolSensor : CoolSensor;
            perform action warmSensor : WarmSensor;
        }
        part def HVPowerSupply {
            attribute outputVoltage : VoltageValue;
            attribute targetVoltage : VoltageValue;
            perform action rampUpHV : RampUpHV;
            perform action rampDownHV : RampDownHV;
        }
        part def ChargeAmplifier {
            port chargeIn : ChargePulseInPort;
            port pulseOut : ElectricalPulseOutPort;
            perform action amplifyCharge : AmplifyCharge;
        }
        part def PulseShapingCircuit {
            port pulseIn : ElectricalPulseInPort;
            port shapedOut : ShapedPulseOutPort;
            perform action shapePulse : ShapePulse;
        }
        part def PulseHeightAnalyzer {
            port shapedIn : ShapedPulseInPort;
            port digitalOut : DigitalEventOutPort;
            perform action analyzePulseHeight : AnalyzePulseHeight;
        }
        part def DataAcquisitionUnit {
            attribute bufferSize : Integer;
            attribute eventCount : Integer;
            port eventIn : DigitalEventInPort;
            port eventOut : DigitalEventOutPort;
            perform action acquireEvent : AcquireEvent;
        }
        part def HPGeDetectorSystem {
            attribute systemId : String;
            attribute maxOperatingTemp : TemperatureValue;
            attribute targetOperatingTemp : TemperatureValue;
            attribute targetHV : VoltageValue;
            port radiationPort : RadiationInPort;
            port dataOutPort : DigitalEventOutPort;
            part sensorCrystal : HPGESensorCrystal;
            part tempController : TemperatureController;
            part hvPowerSupply : HVPowerSupply;
            part chargeAmplifier : ChargeAmplifier;
            part pulseShaper : PulseShapingCircuit;
            part pulseAnalyzer : PulseHeightAnalyzer;
            part daqUnit : DataAcquisitionUnit;
            perform action initializeSystem : InitializeSystem;
            perform action acquireData : AcquireData;
            perform action shutdownSystem : ShutdownSystem;
            exhibit state systemStates : SystemStates;
        }

        requirement def CryogenicCoolingRequirement {
            subject sensor : HPGESensorCrystal;
            objective {
                assert constraint { sensor.operatingTemperature <= 77 [K]; }
            }
        }
        requirement def HVStabilityRequirement {
            subject hvSupply : HVPowerSupply;
            objective {
                assert constraint { hvSupply.outputVoltage >= 2950 [V]; }
                assert constraint { hvSupply.outputVoltage <= 3050 [V]; }
            }
        }
        requirement def DigitalEventRecordingRequirement {
            subject daq : DataAcquisitionUnit;
            objective {
                assert constraint { daq.eventCount >= 0; }
            }
        }
        requirement def SafeShutdownRequirement {
            subject hvSupply : HVPowerSupply;
            objective {
                assert constraint { hvSupply.outputVoltage == 0 [V]; }
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part hpGeDetector : HPGeDetectorSystem {
            attribute systemId = "HPGe-001";
            attribute maxOperatingTemp = 77 [K];
            attribute targetOperatingTemp = 77 [K];
            attribute targetHV = 3000 [V];

            port radiationPort : RadiationInPort;
            port dataOutPort : DigitalEventOutPort;

            part sensorCrystal : HPGESensorCrystal {
                attribute operatingTemperature = 300 [K];
                attribute appliedHV = 0 [V];
            }

            part tempController : TemperatureController {
                attribute targetTemp = 77 [K];
                attribute currentTemp = 300 [K];
            }

            part hvPowerSupply : HVPowerSupply {
                attribute outputVoltage = 0 [V];
                attribute targetVoltage = 3000 [V];
            }

            part chargeAmplifier : ChargeAmplifier;
            part pulseShaper : PulseShapingCircuit;
            part pulseAnalyzer : PulseHeightAnalyzer;

            part daqUnit : DataAcquisitionUnit {
                attribute bufferSize = 10000;
                attribute eventCount = 0;
            }

            connect radiationPort to sensorCrystal.radiationIn;
            connect sensorCrystal.chargeOut to chargeAmplifier.chargeIn;
            connect chargeAmplifier.pulseOut to pulseShaper.pulseIn;
            connect pulseShaper.shapedOut to pulseAnalyzer.shapedIn;
            connect pulseAnalyzer.digitalOut to daqUnit.eventIn;
            connect daqUnit.eventOut to dataOutPort;

            action rampUpHV : RampUpHV;
            action rampDownHV : RampDownHV;
            action coolSensor : CoolSensor;
            action warmSensor : WarmSensor;
            action acquireData : AcquireData;

            state systemStates : SystemStates {
                entry; then standby;

                state standby;
                accept InitSignal
                    then initialization;

                state initialization {
                    entry rampUpHV;
                    do coolSensor;
                }
                accept ReadySignal
                    then operational;

                state operational {
                    entry; then idle;
                    state idle;
                    accept StartAcquisitionSignal
                        then acquiring;
                    accept ShutdownSignal
                        then shutdown;
                    accept MaintenanceSignal
                        then maintenance;
                    state acquiring {
                        do acquireData;
                        accept StopAcquisitionSignal
                            then idle;
                        accept ShutdownSignal
                            then shutdown;
                        accept MaintenanceSignal
                            then maintenance;
                    }
                }

                state maintenance;
                accept ResumeFromMaintenanceSignal
                    then initialization;

                state shutdown {
                    entry rampDownHV;
                    do warmSensor;
                }
                accept ShutdownCompleteSignal
                    then standby;
            }
        }

        requirement cryoCoolingReq : CryogenicCoolingRequirement {
            subject sensor = hpGeDetector.sensorCrystal;
        }
        requirement hvStabilityReq : HVStabilityRequirement {
            subject hvSupply = hpGeDetector.hvPowerSupply;
        }
        requirement digitalEventReq : DigitalEventRecordingRequirement {
            subject daq = hpGeDetector.daqUnit;
        }
        requirement safeShutdownReq : SafeShutdownRequirement {
            subject hvSupply = hpGeDetector.hvPowerSupply;
        }
    }
}
