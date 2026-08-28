package PIDSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def ConcentrationPPM :> ScalarValues::Real;
        attribute def EnergyEV :> ScalarValues::Real;
        
        item def AirSample {
            attribute vocConcentration :> ConcentrationPPM;
        }
        item def IonizedGas;
        item def ElectricalCurrent {
            attribute value :> ISQ::electricCurrent;
        }
        item def VoltageSignal {
            attribute value :> ISQ::electricPotential;
        }
        item def ConcentrationReading {
            attribute value :> ConcentrationPPM;
        }
        item def UVPhoton {
            attribute energy :> EnergyEV;
        }
        item def Power;
        item def AlarmSignal {
            attribute active :> ScalarValues::Boolean;
        }
        
        port def AirFlowPort {
            in item air : AirSample;
            out item air : AirSample;
        }
        port def PhotonPort {
            in item photon : UVPhoton;
            out item photon : UVPhoton;
        }
        port def IonPort {
            in item ions : IonizedGas;
            out item ions : IonizedGas;
        }
        port def CurrentPort {
            in item current : ElectricalCurrent;
            out item current : ElectricalCurrent;
        }
        port def VoltagePort {
            in item voltage : VoltageSignal;
            out item voltage : VoltageSignal;
        }
        port def ConcentrationPort {
            in item concentration : ConcentrationReading;
            out item concentration : ConcentrationReading;
        }
        port def AlarmPort {
            in item alarm : AlarmSignal;
            out item alarm : AlarmSignal;
        }
        port def PowerPort {
            in item power : Power;
            out item power : Power;
        }
        
        action def DrawSample {
            in air : AirSample;
            out sampledAir : AirSample;
        }
        action def EmitPhotons {
            out photon : UVPhoton;
        }
        action def IonizeVOCs {
            in air : AirSample;
            in photon : UVPhoton;
            out ions : IonizedGas;
        }
        action def CollectIons {
            in ions : IonizedGas;
            out current : ElectricalCurrent;
        }
        action def AmplifyCurrent {
            in current : ElectricalCurrent;
            out voltage : VoltageSignal;
        }
        action def ProcessSignal {
            in voltage : VoltageSignal;
            out concentration : ConcentrationReading;
        }
        action def MonitorConcentration {
            in concentration : ConcentrationReading;
            out alarm : AlarmSignal;
        }
        action def DetectVOC {
            in air : AirSample;
            out concentration : ConcentrationReading;
            out alarm : AlarmSignal;
        }
        action def WarmupLamp;
        action def TriggerAlarm;
        action def LogError;
        action def InitializeSystem;
        action def DistributePower;
        
        attribute def PowerOnSignal;
        attribute def PowerOffSignal;
        attribute def InitializationCompleteSignal;
        attribute def WarmupCompleteSignal;
        attribute def StartMeasureSignal;
        attribute def StopMeasureSignal;
        attribute def HighConcentrationAlert;
        attribute def AlarmClearedSignal;
        attribute def FaultSignal;
        attribute def ResetSignal;
        
        state def PIDStates;
        
        part def PIDSystem {
            attribute alarmThreshold :> ConcentrationPPM = 100.0;
            port airIntake : AirFlowPort;
            port dataOutput : ConcentrationPort;
            port alarmOutput : AlarmPort;
            port powerInput : PowerPort;
            perform action 'detect voc' : DetectVOC;
            exhibit state 'pid states' : PIDStates;
        }
        part def SamplePump {
            attribute flowRate :> ISQ::volumeFlowRate;
            port airIn : AirFlowPort;
            port airOut : AirFlowPort;
            port powerIn : PowerPort;
            perform action drawSample : DrawSample;
        }
        part def IonizationChamber {
            port airIn : AirFlowPort;
            port photonIn : PhotonPort;
            port ionOut : IonPort;
            port powerIn : PowerPort;
            perform action ionizeVOCs : IonizeVOCs;
        }
        part def UVLamp {
            attribute energyLevel :> EnergyEV = 10.6;
            port lightOut : PhotonPort;
            port powerIn : PowerPort;
            perform action emitPhotons : EmitPhotons;
        }
        part def CollectorElectrodes {
            attribute voltageDifference :> ISQ::electricPotential;
            port ionIn : IonPort;
            port currentOut : CurrentPort;
            port powerIn : PowerPort;
            perform action collectIons : CollectIons;
        }
        part def CurrentAmplifier {
            attribute gain :> ScalarValues::Real;
            port currentIn : CurrentPort;
            port voltageOut : VoltagePort;
            port powerIn : PowerPort;
            perform action amplifyCurrent : AmplifyCurrent;
        }
        part def SignalProcessor {
            attribute calibrationCurve : ScalarValues::Real[0..*];
            port voltageIn : VoltagePort;
            port concentrationOut : ConcentrationPort;
            port powerIn : PowerPort;
            perform action processSignal : ProcessSignal;
        }
        part def AlarmSystem {
            attribute threshold :> ConcentrationPPM = 100.0;
            port concentrationIn : ConcentrationPort;
            port alarmOut : AlarmPort;
            port powerIn : PowerPort;
            perform action monitorConcentration : MonitorConcentration;
        }
        part def PowerSupply {
            attribute outputVoltage :> ISQ::electricPotential;
            port powerOut : PowerPort;
            perform action distributePower : DistributePower;
        }
        
        requirement def VOCDetectionRequirement {
            doc /* The PID system shall detect and measure VOC concentration in air. */
            subject pid : PIDSystem;
            objective {
                pid.'detect voc'
            }
        }
        requirement def UVLampEnergyRequirement {
            doc /* The UV lamp shall operate at 10.6 eV energy level. */
            subject lamp : UVLamp;
            objective {
                lamp.energyLevel == 10.6
            }
        }
        requirement def AlarmThresholdRequirement {
            doc /* The alarm shall trigger when concentration exceeds 100 ppm. */
            subject alarm : AlarmSystem;
            objective {
                alarm.threshold == 100.0
            }
        }
        requirement def WarmupTimeRequirement {
            doc /* The UV lamp shall stabilize within 30 seconds of power on. */
            subject lamp : UVLamp;
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        action 'detect voc' : DetectVOC {
            in air : AirSample;
            out concentration : ConcentrationReading;
            out alarm : AlarmSignal;
            loop {
                action 'draw sample' : DrawSample {
                    in air = 'detect voc'::air;
                    out sampledAir : AirSample;
                }
                flow 'draw sample'.sampledAir to 'ionize vocs'.air;
                action 'emit photons' : EmitPhotons {
                    out photon : UVPhoton;
                }
                flow 'emit photons'.photon to 'ionize vocs'.photon;
                action 'ionize vocs' : IonizeVOCs {
                    in air : AirSample;
                    in photon : UVPhoton;
                    out ions : IonizedGas;
                }
                flow 'ionize vocs'.ions to 'collect ions'.ions;
                action 'collect ions' : CollectIons {
                    in ions : IonizedGas;
                    out current : ElectricalCurrent;
                }
                flow 'collect ions'.current to 'amplify current'.current;
                action 'amplify current' : AmplifyCurrent {
                    in current : ElectricalCurrent;
                    out voltage : VoltageSignal;
                }
                flow 'amplify current'.voltage to 'process signal'.voltage;
                action 'process signal' : ProcessSignal {
                    in voltage : VoltageSignal;
                    out concentration : ConcentrationReading;
                }
                flow 'process signal'.concentration to 'monitor concentration'.concentration;
                action 'monitor concentration' : MonitorConcentration {
                    in concentration : ConcentrationReading;
                    out alarm : AlarmSignal;
                }
                flow 'process signal'.concentration to 'detect voc'::concentration;
                flow 'monitor concentration'.alarm to 'detect voc'::alarm;
            }
        }
        
        action 'warmup lamp' : WarmupLamp;
        action 'trigger alarm' : TriggerAlarm;
        action 'log error' : LogError;
        action 'initialize system' : InitializeSystem;
        
        state 'pid states' : PIDStates parallel {
            state 'operational states' {
                entry; then off;
                state off;
                accept PowerOnSignal
                    then initializing;
                state initializing {
                    do 'initialize system';
                }
                accept InitializationCompleteSignal
                    then warmup;
                state warmup {
                    do 'warmup lamp';
                }
                accept WarmupCompleteSignal
                    then ready;
                state ready;
                accept StartMeasureSignal
                    then measuring;
                accept FaultSignal
                    then fault;
                state measuring {
                    do 'detect voc';
                }
                accept StopMeasureSignal
                    then ready;
                accept FaultSignal
                    then fault;
                state fault {
                    do 'log error';
                }
                accept ResetSignal
                    then off;
                accept PowerOffSignal
                    then off;
            }
            state 'alarm states' {
                entry; then normal;
                state normal;
                accept HighConcentrationAlert
                    then alarm;
                state alarm {
                    do 'trigger alarm';
                }
                accept AlarmClearedSignal
                    then normal;
            }
        }
        
        part pidSystem : PIDSystem {
            part powerSupply : PowerSupply;
            part samplePump : SamplePump;
            part uvLamp : UVLamp;
            part ionizationChamber : IonizationChamber;
            part collectorElectrodes : CollectorElectrodes;
            part currentAmplifier : CurrentAmplifier;
            part signalProcessor : SignalProcessor;
            part alarmSystem : AlarmSystem;
            
            connect airIntake to samplePump.airIn;
            connect samplePump.airOut to ionizationChamber.airIn;
            connect uvLamp.lightOut to ionizationChamber.photonIn;
            connect ionizationChamber.ionOut to collectorElectrodes.ionIn;
            connect collectorElectrodes.currentOut to currentAmplifier.currentIn;
            connect currentAmplifier.voltageOut to signalProcessor.voltageIn;
            connect signalProcessor.concentrationOut to dataOutput;
            connect signalProcessor.concentrationOut to alarmSystem.concentrationIn;
            connect alarmSystem.alarmOut to alarmOutput;
            
            connect powerSupply.powerOut to samplePump.powerIn;
            connect powerSupply.powerOut to uvLamp.powerIn;
            connect powerSupply.powerOut to ionizationChamber.powerIn;
            connect powerSupply.powerOut to collectorElectrodes.powerIn;
            connect powerSupply.powerOut to currentAmplifier.powerIn;
            connect powerSupply.powerOut to signalProcessor.powerIn;
            connect powerSupply.powerOut to alarmSystem.powerIn;
        }
        
        satisfy VOCDetectionRequirement by pidSystem;
        satisfy UVLampEnergyRequirement by pidSystem.uvLamp;
        satisfy AlarmThresholdRequirement by pidSystem.alarmSystem;
        satisfy WarmupTimeRequirement by pidSystem.uvLamp;
    }
}
