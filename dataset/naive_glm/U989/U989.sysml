package AirDefenseSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def DistanceKm :> Real { unit 'km'; }
    value def VelocityMps :> Real { unit 'm/s'; }
    value def AngleDeg :> Real { unit 'deg'; }
    value def Probability :> Real { unit '1'; }
    value def TimeSec :> Real { unit 's'; }

    // ===== Item Types =====
    item def RadarReturn {
        attribute range : DistanceKm;
        attribute azimuth : AngleDeg;
        attribute elevation : AngleDeg;
        attribute signalStrength : Real;
    }

    item def IRSignature {
        attribute azimuth : AngleDeg;
        attribute elevation : AngleDeg;
        attribute thermalIntensity : Real;
    }

    item def Track {
        attribute trackId : Integer;
        attribute positionX : DistanceKm;
        attribute positionY : DistanceKm;
        attribute positionZ : DistanceKm;
        attribute velocityX : VelocityMps;
        attribute velocityY : VelocityMps;
        attribute velocityZ : VelocityMps;
        attribute confidence : Probability;
        attribute stable : Boolean;
    }

    item def ThreatAssessment {
        attribute trackId : Integer;
        attribute threatLevel : ThreatLevel;
        attribute hostile : Boolean;
    }

    enum def ThreatLevel { low; medium; high; }

    item def ThreatAlert {
        attribute trackId : Integer;
        attribute level : ThreatLevel;
        attribute timestamp : TimeSec;
    }

    item def FireCommand {
        attribute trackId : Integer;
        attribute missileSystemId : Integer;
        attribute authorizationCode : String;
    }

    item def Interceptor {
        attribute missileId : Integer;
        attribute maxRange : DistanceKm := 45.0;
        attribute ready : Boolean;
    }

    item def EngagementResult {
        attribute trackId : Integer;
        attribute success : Boolean;
    }

    // ===== Port Definitions =====
    port def RadarOutPort { out radarReturns : RadarReturn; }
    port def IROutPort { out irSignatures : IRSignature; }
    port def TrackOutPort { out tracks : Track; }
    port def AssessmentOutPort { out assessments : ThreatAssessment; }
    port def AlertOutPort { out alerts : ThreatAlert; }
    port def FireCmdOutPort { out fireCommands : FireCommand; }
    port def ResultOutPort { out results : EngagementResult; }

    // ===== Requirements =====
    requirement def DetectThreats {
        subject : AirDefenseSystem;
        objective {
            doc "The system shall autonomously detect airborne threats within 50 km using radar and IR sensors.";
        }
        assume { radarRange >= 50.0; }
    }

    requirement def ManageTracks {
        subject : TrackingProcessor;
        objective {
            doc "The tracking processor shall manage up to 50 simultaneous target tracks.";
        }
        assume { maxTracks <= 50; }
    }

    requirement def AssessThreat {
        subject : ThreatAssessmentEngine;
        objective {
            doc "The engine shall classify tracks and generate alerts for high-level threats.";
        }
    }

    requirement def EngageTarget {
        subject : WeaponController;
        objective {
            doc "The controller shall issue fire commands to one of two missile systems for targets up to 45 km.";
        }
        assume { interceptorRange >= 45.0; }
    }

    requirement def AutonomousOperation {
        subject : AirDefenseSystem;
        objective {
            doc "The system shall operate fully autonomously through monitoring, tracking, assessing, and engaging states.";
        }
    }

    // ===== Parts =====
    part def LongRangeRadar {
        attribute maxRange : DistanceKm := 50.0;
        attribute scanRateHz : Real := 10.0;
        port radarOut : RadarOutPort;
        exhibit state behavior {
            entry; then Scanning;
            state Scanning;
            transition Scanning -> Scanning
                when true
                do { send radarOut.radarReturns << RadarReturn{range=0.0, azimuth=0.0, elevation=0.0, signalStrength=0.0} >>; }
            ;
        }
    }

    part def IRSensor {
        attribute sensitivity : Real := 0.95;
        port irOut : IROutPort;
        exhibit state behavior {
            entry; then Detecting;
            state Detecting;
            transition Detecting -> Detecting
                when true
                do { send irOut.irSignatures << IRSignature{azimuth=0.0, elevation=0.0, thermalIntensity=0.0} >>; }
            ;
        }
    }

    part def SensorSuite {
        part radar : LongRangeRadar;
        part ir : IRSensor;
        port radarOut : RadarOutPort;
        port irOut : IROutPort;
        connection radar.radarOut to radarOut;
        connection ir.irOut to irOut;
    }

    part def TrackingProcessor {
        attribute maxTracks : Integer := 50;
        attribute activeTracks : Integer := 0;
        port radarIn : RadarOutPort;
        port irIn : IROutPort;
        port trackOut : TrackOutPort;
        exhibit state behavior {
            entry; then Idle;
            state Idle;
            transition Idle -> Processing
                when { radarIn.radarReturns->notEmpty() or irIn.irSignatures->notEmpty() }
                do { activeTracks := activeTracks + 1; }
            ;
            state Processing;
            transition Processing -> Idle
                when true
                do { send trackOut.tracks << Track{trackId=1, positionX=0.0, positionY=0.0, positionZ=0.0, velocityX=0.0, velocityY=0.0, velocityZ=0.0, confidence=0.9, stable=true} >>; }
            ;
        }
    }

    part def ThreatAssessmentEngine {
        attribute rulesetVersion : String := "v2.3";
        port trackIn : TrackOutPort;
        port assessmentOut : AssessmentOutPort;
        port alertOut : AlertOutPort;
        exhibit state behavior {
            entry; then Evaluating;
            state Evaluating;
            transition Evaluating -> Evaluating
                when { trackIn.tracks->notEmpty() }
                do {
                    send assessmentOut.assessments << ThreatAssessment{trackId=1, threatLevel=ThreatLevel::high, hostile=true} >>;
                    send alertOut.alerts << ThreatAlert{trackId=1, level=ThreatLevel::high, timestamp=0.0} >>;
                }
            ;
        }
    }

    part def MissileSystem {
        attribute systemId : Integer;
        attribute interceptors : Interceptor[4];
        port fireCmdIn : FireCmdOutPort;
        port resultOut : ResultOutPort;
        exhibit state behavior {
            entry; then Ready;
            state Ready;
            transition Ready -> Launching
                when { fireCmdIn.fireCommands->notEmpty() }
                do { /* launch interceptor */ }
            ;
            state Launching;
            transition Launching -> Ready
                when true
                do { send resultOut.results << EngagementResult{trackId=1, success=true} >>; }
            ;
        }
    }

    part def WeaponController {
        attribute authorizationEnabled : Boolean := true;
        port alertIn : AlertOutPort;
        port fireCmdOut1 : FireCmdOutPort;
        port fireCmdOut2 : FireCmdOutPort;
        exhibit state behavior {
            entry; then Standby;
            state Standby;
            transition Standby -> Authorizing
                when { alertIn.alerts->notEmpty() }
                do { /* verify engagement parameters */ }
            ;
            state Authorizing;
            transition Authorizing -> Standby
                when true
                do { send fireCmdOut1.fireCommands << FireCommand{trackId=1, missileSystemId=1, authorizationCode="AUTH-001"} >>; }
            ;
        }
    }

    part def AirDefenseSystem {
        attribute operationalArea : String := "Sector-A1";
        satisfy DetectThreats;
        satisfy AutonomousOperation;

        part sensorSuite : SensorSuite;
        part trackingProcessor : TrackingProcessor;
        part threatEngine : ThreatAssessmentEngine;
        part weaponController : WeaponController;
        part missileSystem1 : MissileSystem { systemId = 1; }
        part missileSystem2 : MissileSystem { systemId = 2; }

        connection sensorSuite.radarOut to trackingProcessor.radarIn;
        connection sensorSuite.irOut to trackingProcessor.irIn;
        connection trackingProcessor.trackOut to threatEngine.trackIn;
        connection threatEngine.assessmentOut to weaponController.alertIn;
        connection threatEngine.alertOut to weaponController.alertIn;
        connection weaponController.fireCmdOut1 to missileSystem1.fireCmdIn;
        connection weaponController.fireCmdOut2 to missileSystem2.fireCmdIn;
        connection missileSystem1.resultOut to weaponController.alertIn;
        connection missileSystem2.resultOut to weaponController.alertIn;

        exhibit state behavior {
            entry; then Monitoring;
            state Monitoring;
            transition Monitoring -> Tracking
                when { sensorSuite.radarOut.radarReturns->notEmpty() or sensorSuite.irOut.irSignatures->notEmpty() }
                do { /* begin tracking */ }
            ;
            state Tracking;
            transition Tracking -> Assessing
                when { trackingProcessor.trackOut.tracks->notEmpty() }
                do { /* stable track established */ }
            ;
            state Assessing;
            transition Assessing -> Engaging
                when { threatEngine.alertOut.alerts->notEmpty() }
                do { /* high-level threat confirmed */ }
            ;
            state Engaging;
            transition Engaging -> Monitoring
                when { missileSystem1.resultOut.results->notEmpty() or missileSystem2.resultOut.results->notEmpty() }
                guard { missileSystem1.resultOut.results->any().success }
                do { /* intercept successful */ }
            ;
            transition Engaging -> Engaging
                when { missileSystem1.resultOut.results->notEmpty() or missileSystem2.resultOut.results->notEmpty() }
                guard { not missileSystem1.resultOut.results->any().success }
                do { /* re-engage target */ }
            ;
        }
    }
}
