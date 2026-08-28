package SailVesselModel {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value def Length :> Real { unit 'm'; }
    value def Mass :> Real { unit 'kg'; }
    value def Area :> Real { unit 'm2'; }
    value def Speed :> Real { unit 'm/s'; }
    value def Angle :> Real { unit 'deg'; }
    value def Force :> Real { unit 'N'; }
    value def Tension :> Real { unit 'N'; }

    // ===== Item Types =====
    item def Wind {
        attribute speed : Speed;
        attribute direction : Angle; // apparent wind angle relative to vessel centerline
    }

    item def SailForces {
        attribute lift : Force;
        attribute drag : Force;
        attribute propulsive : Force;
        attribute lateral : Force;
    }

    // ===== Requirements =====
    requirement def ThrustRequirement {
        doc /* The vessel must generate minimum thrust under specified wind conditions. */
        attribute minThrust : Force = 800 [N];
        attribute windSpeed : Speed = 6 [m/s];
        subject vessel : SailVessel;
        require { vessel.sailSystem.propulsiveForce >= minThrust when vessel.apparentWind.speed == windSpeed; }
    }

    requirement def OperatingWindRange {
        doc /* Operate safely within a defined range of wind speeds. */
        attribute minWind : Speed = 2 [m/s];
        attribute maxWind : Speed = 15 [m/s];
        subject vessel : SailVessel;
        require { vessel.apparentWind.speed >= minWind and vessel.apparentWind.speed <= maxWind implies vessel.state == OperatingState::sailing; }
    }

    requirement def StructuralIntegrity {
        doc /* Meet structural integrity standards to prevent failure. */
        attribute maxRiggingTension : Tension = 25000 [N];
        subject vessel : SailVessel;
        require { vessel.sailSystem.rigging.maxTension <= maxRiggingTension; }
    }

    requirement def HeelSafetyConstraint {
        doc /* Limit heel angle to a maximum of 35 degrees during normal operation. */
        attribute maxHeelAngle : Angle = 35 [deg];
        subject vessel : SailVessel;
        require { vessel.heelAngle <= maxHeelAngle when vessel.state == OperatingState::sailing; }
    }

    requirement VesselRequirements :> ThrustRequirement, OperatingWindRange, StructuralIntegrity, HeelSafetyConstraint {
        subject vessel : SailVessel;
    }

    // ===== Enumerations =====
    enum def OperatingState { idle; sailing; reefed; emergency; }

    // ===== Parts =====
    part def Hull {
        attribute length : Length = 12 [m];
        attribute displacement : Mass = 4000 [kg];
        port in propulsionInput : Force;
        port in lateralInput : Force;
        port out speedOut : Speed;
        port out heelAngleOut : Angle;
        attribute speed : Speed;
        attribute heelAngle : Angle;
        compute speed { :>> speed = propulsionInput / 50 [kg/s]; }
        compute heelAngle { :>> heelAngle = lateralInput / 1000 [N/deg]; }
    }

    part def Rudder {
        attribute length : Length = 1.2 [m];
        port in commandedAngle : Angle;
        port in vesselSpeed : Speed;
        port out steeringForce : Force;
        attribute angle : Angle;
        compute steeringForce { :>> steeringForce = vesselSpeed * angle * 10 [N*s/(m*deg)]; }
    }

    part def Sail {
        attribute area : Area = 40 [m2];
        attribute material : String = "Dacron";
        port in commandedAngle : Angle;
        port in apparentWind : Wind;
        port out sailAngle : Angle;
        port out forces : SailForces;
        attribute angle : Angle;
        compute angle { :>> angle = commandedAngle; }
        compute forces {
            :>> forces.lift = apparentWind.speed ** 2 * area * 0.8 * sin(commandedAngle);
            :>> forces.drag = apparentWind.speed ** 2 * area * 0.3 * cos(commandedAngle);
            :>> forces.propulsive = forces.lift * cos(apparentWind.direction) - forces.drag * sin(apparentWind.direction);
            :>> forces.lateral = forces.lift * sin(apparentWind.direction) + forces.drag * cos(apparentWind.direction);
        }
    }

    part def Mast {
        attribute height : Length = 15 [m];
        attribute material : String = "Aluminum";
    }

    part def Boom {
        attribute length : Length = 5 [m];
        attribute material : String = "Aluminum";
    }

    part def Rigging {
        attribute maxTension : Tension = 25000 [N];
        attribute material : String = "Stainless Steel";
        port in load : Tension;
        attribute currentTension : Tension;
        compute currentTension { :>> currentTension = load; }
    }

    part def SailSystem {
        part sail : Sail;
        part mast : Mast;
        part boom : Boom;
        part rigging : Rigging;
        port in commandedSailAngle : Angle;
        port in apparentWind : Wind;
        port out propulsiveForce : Force;
        port out lateralForce : Force;
        port out riggingLoad : Tension;
        attribute propulsiveForce : Force;
        attribute lateralForce : Force;
        flow sail.commandedAngle < commandedSailAngle;
        flow sail.apparentWind < apparentWind;
        flow rigging.load < sail.forces.lateral;
        compute propulsiveForce { :>> propulsiveForce = sail.forces.propulsive; }
        compute lateralForce { :>> lateralForce = sail.forces.lateral; }
        compute riggingLoad { :>> riggingLoad = rigging.currentTension; }
    }

    part def SailVessel {
        part hull : Hull;
        part rudder : Rudder;
        part sailSystem : SailSystem;
        port in commandedSailAngle : Angle;
        port in commandedRudderAngle : Angle;
        port in apparentWind : Wind;
        port out vesselSpeed : Speed;
        port out heelAngle : Angle;
        attribute apparentWind : Wind;
        attribute heelAngle : Angle;
        attribute state : OperatingState = OperatingState::idle;
        satisfy VesselRequirements { subject vessel = SailVessel::this; }
        flow sailSystem.commandedSailAngle < commandedSailAngle;
        flow sailSystem.apparentWind < apparentWind;
        flow hull.propulsionInput < sailSystem.propulsiveForce;
        flow hull.lateralInput < sailSystem.lateralForce;
        flow rudder.commandedAngle < commandedRudderAngle;
        flow rudder.vesselSpeed < hull.speedOut;
        flow vesselSpeed < hull.speedOut;
        flow heelAngle < hull.heelAngleOut;
        state def Behavior {
            entry; then idle;
            state idle;
            state sailing;
            state reefed;
            state emergency;
            transition idle_to_sailing
                first idle
                if apparentWind.speed >= 2 [m/s] and apparentWind.speed <= 15 [m/s]
                then sailing;
            transition sailing_to_reefed
                first sailing
                if heelAngle > 30 [deg]
                then reefed;
            transition reefed_to_sailing
                first reefed
                if heelAngle <= 25 [deg]
                then sailing;
            transition any_to_emergency
                first sailing
                if heelAngle > 35 [deg] or apparentWind.speed > 15 [m/s]
                then emergency;
            transition emergency_to_idle
                first emergency
                if apparentWind.speed < 2 [m/s]
                then idle;
        }
        exhibit Behavior;
    }

    // ===== Instance =====
    part vesselInstance : SailVessel {
        attribute :>> apparentWind = Wind{speed = 8 [m/s]; direction = 45 [deg];};
    }
}
