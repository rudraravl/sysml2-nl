package AirDefenseSystemModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        alias Distance for ISQ::LengthValue;
        alias Velocity for ISQ::SpeedValue;

        item def RadarData;
        item def InfraredData;
        item def FusedSensorData;
        item def TrackData {
            attribute trackId: String;
            attribute position: Distance[3];
            attribute velocity: Velocity[3];
            attribute isStable: Boolean;
        }
        item def ThreatAlert {
            attribute threatLevel: Integer;
            attribute targetTrackId: String;
        }
        item def FireCommand {
            attribute targetTrackId: String;
            attribute missileSystemId: String;
        }
        item def InterceptResult {
            attribute success: Boolean;
        }

        item def StableTrackEstablished;
        item def TrackDataReady;
        item def HighThreatAlert;
        item def InterceptSuccessful;
        item def InterceptFailed;

        port def RadarDataPort { out radarData: RadarData; }
        port def IRDataPort { out irData: InfraredData; }
        port def TrackDataPort { out track: TrackData; }
        port def ThreatAlertPort { out alert: ThreatAlert; }
        port def FireCommandPort { out command: FireCommand; }
        port def InterceptResultPort { out result: InterceptResult; }

        action def ScanRadar { out radarData: RadarData; }
        action def ScanIR { out irData: InfraredData; }
        action def ScanEnvironment {
            action scanRadar : ScanRadar;
            action scanIR : ScanIR;
        }
        action def FuseAndTrack {
            in radarData: RadarData;
            in irData: InfraredData;
            out fusedData: FusedSensorData;
            out track: TrackData;
        }
        action def AssessThreat {
            in track: TrackData;
            out alert: ThreatAlert;
        }
        action def VerifyAndFire {
            in alert: ThreatAlert;
            out command1: FireCommand;
            out command2: FireCommand;
        }
        action def LaunchMissile {
            in command: FireCommand;
            out result: InterceptResult;
        }
        action def EngageTarget {
            action verifyAndFire : VerifyAndFire;
            action launch1 : LaunchMissile;
            action launch2 : LaunchMissile;
        }

        part def RadarSensor {
            attribute maxRange: Distance = 50 [km];
            port radarPort : RadarDataPort;
        }
        part def InfraredSensor {
            port irPort : IRDataPort;
        }
        part def SensorSuite {
            part radar: RadarSensor;
            part irSensor: InfraredSensor;
            port radarPort : RadarDataPort;
            port irPort : IRDataPort;

            connect radar.radarPort to radarPort;
            connect irSensor.irPort to irPort;
        }
        part def TrackingProcessor {
            attribute maxTracks: Integer = 50;
            port radarDataPort : ~RadarDataPort;
            port irDataPort : ~IRDataPort;
            port trackPort : TrackDataPort;
        }
        part def ThreatAssessmentEngine {
            port trackPort : ~TrackDataPort;
            port alertPort : ThreatAlertPort;
        }
        part def WeaponController {
            port alertPort : ~ThreatAlertPort;
            port firePort1 : FireCommandPort;
            port firePort2 : FireCommandPort;
            port resultPort : ~InterceptResultPort;
        }
        part def InterceptorMissile {
            attribute maxRange: Distance = 45 [km];
        }
        part def MissileSystem {
            attribute systemId: String;
            port commandPort : ~FireCommandPort;
            port resultPort : InterceptResultPort;
            part missiles: InterceptorMissile [1..*];
        }
        part def AirDefenseSystem {
            part sensorSuite: SensorSuite;
            part trackingProcessor: TrackingProcessor;
            part threatAssessment: ThreatAssessmentEngine;
            part weaponController: WeaponController;
            part missileSystem1: MissileSystem;
            part missileSystem2: MissileSystem;

            connect sensorSuite.radarPort to trackingProcessor.radarDataPort;
            connect sensorSuite.irPort to trackingProcessor.irDataPort;
            connect trackingProcessor.trackPort to threatAssessment.trackPort;
            connect threatAssessment.alertPort to weaponController.alertPort;
            connect weaponController.firePort1 to missileSystem1.commandPort;
            connect weaponController.firePort2 to missileSystem2.commandPort;
            connect missileSystem1.resultPort to weaponController.resultPort;
            connect missileSystem2.resultPort to weaponController.resultPort;

            exhibit state defenseStates: DefenseStates;
        }

        state def DefenseStates {
            entry; then monitoring;
            state monitoring {
                do action scanEnvironment : ScanEnvironment;
            }
            transition monitoring_to_tracking
                first monitoring
                accept StableTrackEstablished
                then tracking;
            state tracking {
                do action fuseAndTrack : FuseAndTrack;
            }
            transition tracking_to_assessing
                first tracking
                accept TrackDataReady
                then assessing;
            state assessing {
                do action assessThreat : AssessThreat;
            }
            transition assessing_to_engaging
                first assessing
                accept HighThreatAlert
                then engaging;
            state engaging {
                do action engageTarget : EngageTarget;
            }
            transition engaging_to_monitoring
                first engaging
                accept InterceptSuccessful
                then monitoring;
            transition engaging_to_tracking
                first engaging
                accept InterceptFailed
                then tracking;
        }
    }

    package Usages {
        private import Definitions::*;

        part airDefenseSystem: AirDefenseSystem;
    }

    package Requirements {
        private import Definitions::*;
        requirement def AirDefenseSystemRequirements {
            subject airDefenseSystem: AirDefenseSystem;
            requirement sensorSuiteRange {
                doc /* The radar sensor shall have a maximum range of at least 50 km. */
            }
            requirement processorTrackCapacity {
                doc /* The tracking processor shall manage up to 50 distinct target tracks simultaneously. */
            }
            requirement interceptorRange {
                doc /* Each interceptor missile shall be capable of engaging targets up to 45 km away. */
            }
            requirement autonomousEngagement {
                doc /* The system shall autonomously transition from monitoring to engaging upon threat detection. */
            }
        }
    }
}
