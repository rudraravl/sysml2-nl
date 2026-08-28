package SailboatModel {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::String;

    port def WindInputPort {
        attribute windSpeed :> ISQ::speed;
        attribute windDirection :> ISQ::planeAngle;
    }
    port def SailCommandPort {
        attribute sailAngleCmd :> ISQ::planeAngle;
    }
    port def ForceTransferPort {
        attribute thrust :> ISQ::force;
        attribute lateralForce :> ISQ::force;
    }
    port def VesselStatePort {
        attribute vesselSpeed :> ISQ::speed;
        attribute heelAngle :> ISQ::planeAngle;
    }
    port def RudderCommandPort {
        attribute rudderAngleCmd :> ISQ::planeAngle;
    }
    port def HullAttachmentPort;

    item def DacronFabric;

    action def CaptureWind {
        in windSpeed :> ISQ::speed;
        in windDirection :> ISQ::planeAngle;
        in sailAngle :> ISQ::planeAngle;
        out thrust :> ISQ::force;
        out lateralForce :> ISQ::force;
    }
    action def ResolveForces {
        in lift :> ISQ::force;
        in drag :> ISQ::force;
        out thrust :> ISQ::force;
        out lateralForce :> ISQ::force;
    }
    action def GeneratePropulsion {
        in windSpeed :> ISQ::speed;
        in windDirection :> ISQ::planeAngle;
        in sailAngle :> ISQ::planeAngle;
        out thrust :> ISQ::force;
        out lateralForce :> ISQ::force;
    }
    action def SteerVessel {
        in rudderAngle :> ISQ::planeAngle;
        out headingChange :> ISQ::planeAngle;
    }
    action def MonitorVesselState {
        out vesselSpeed :> ISQ::speed;
        out heelAngle :> ISQ::planeAngle;
    }
    action def CastOff;
    action def Dock;

    part def Hull {
        attribute length :> ISQ::length = 12 [m];
        attribute displacement :> ISQ::mass = 4000 [kg];
        attribute speed :> ISQ::speed;
        attribute heelAngle :> ISQ::planeAngle;
        port forcePort : ForceTransferPort;
        port rudderAttachment : HullAttachmentPort;
        port vesselStatePort : VesselStatePort;
        perform action moveThroughWater;
        perform action resistLateralForce;
    }

    part def Rudder {
        attribute angle :> ISQ::planeAngle;
        port hullAttachment : ~HullAttachmentPort;
        port commandPort : RudderCommandPort;
        perform action steer : SteerVessel;
    }

    part def Sail {
        attribute area :> ISQ::area = 40 [m^2];
        attribute material : String = "Dacron";
        item fabric : DacronFabric;
        attribute angle :> ISQ::planeAngle;
        port windPort : WindInputPort;
        port cmdPort : SailCommandPort;
        port forcePort : ForceTransferPort;
        perform action captureWind : CaptureWind;
    }

    part def Mast {
        attribute height :> ISQ::length = 15 [m];
        attribute material : String = "Aluminum";
        port hullAttachment : ~HullAttachmentPort;
        port sailAttachment;
        port riggingAttachment[3];
    }

    part def Boom {
        attribute length :> ISQ::length = 5 [m];
        attribute material : String = "Aluminum";
        port mastAttachment;
        port sailAttachment;
    }

    part def Rigging {
        attribute maxTensileForce :> ISQ::force = 50000 [N];
        attribute material : String = "Stainless Steel";
        port mastAttachment[3];
        port hullAttachment[3] : ~HullAttachmentPort;
        perform action transferLoads;
    }

    part def SailSystem {
        part sail : Sail;
        part mast : Mast;
        part boom : Boom;
        part rigging : Rigging;

        port windPort : WindInputPort = sail.windPort;
        port cmdPort : SailCommandPort = sail.cmdPort;
        port forcePort : ForceTransferPort = sail.forcePort;
        port hullAttachment : HullAttachmentPort;

        perform action generatePropulsion : GeneratePropulsion;
        perform action trimSail;
    }

    part def Sailboat {
        attribute length :> ISQ::length = 12 [m];
        attribute displacement :> ISQ::mass = 4000 [kg];
        attribute speed :> ISQ::speed;
        attribute heelAngle :> ISQ::planeAngle;

        port windPort : WindInputPort;
        port sailCmdPort : SailCommandPort;
        port rudderCmdPort : RudderCommandPort;
        port vesselStatePort : VesselStatePort;

        part hull : Hull;
        part rudder : Rudder;
        part sailSystem : SailSystem;

        perform action captureWind;
        perform action monitorState : MonitorVesselState;

        exhibit state operatingStates {
            state docked {
                entry action secureVessel;
            }
            state sailing {
                entry action raiseSails;
                do captureWind;
                do monitorState;
                exit action lowerSails;
            }
            state heeling {
                do monitorState;
                constraint { heelAngle <= 35 [deg] }
            }
            transition docked_to_sailing
                first docked
                accept CastOff
                then sailing;
            transition sailing_to_docked
                first sailing
                accept Dock
                then docked;
            transition sailing_to_heeling
                first sailing
                when heelAngle > 5 [deg]
                then heeling;
            transition heeling_to_sailing
                first heeling
                when heelAngle <= 5 [deg]
                then sailing;
        }
    }

    requirement def <'1'> MinimumThrustRequirement {
        doc /* The sailboat shall generate a minimum propulsive thrust under specific wind conditions. */
        subject sailboat : Sailboat;
        attribute windSpeed :> ISQ::speed;
        attribute sailAngle :> ISQ::planeAngle;
        attribute minThrust :> ISQ::force;
        attribute actualThrust :> ISQ::force;
        require constraint { windSpeed == 10 [m/s] and sailAngle == 45 [deg] implies actualThrust >= minThrust }
    }

    requirement def <'2'> SafeWindSpeedRequirement {
        doc /* The sailboat shall operate safely within a defined range of wind speeds. */
        subject sailboat : Sailboat;
        attribute minWindSpeed :> ISQ::speed;
        attribute maxWindSpeed :> ISQ::speed;
        attribute currentWindSpeed :> ISQ::speed;
        require constraint { currentWindSpeed >= minWindSpeed and currentWindSpeed <= maxWindSpeed }
    }

    requirement def <'3'> StructuralIntegrityRequirement {
        doc /* The rigging shall withstand tensile forces up to its maximum rated load without failure. */
        subject rigging : Rigging;
        attribute maxTensileForce :> ISQ::force;
        attribute appliedForce :> ISQ::force;
        require constraint { appliedForce <= maxTensileForce }
    }

    requirement def <'4'> HeelAngleLimitRequirement {
        doc /* The heel angle shall not exceed 35 degrees during normal operation. */
        subject sailboat : Sailboat;
        attribute maxHeelAngle :> ISQ::planeAngle = 35 [deg];
        attribute actualHeelAngle :> ISQ::planeAngle;
        require constraint { actualHeelAngle <= maxHeelAngle }
    }

    part mySailboat : Sailboat {
        attribute :>> length = 12 [m];
        attribute :>> displacement = 4000 [kg];

        part :>> hull : Hull {
            attribute :>> length = 12 [m];
            attribute :>> displacement = 4000 [kg];
        }

        part :>> rudder : Rudder {
            attribute :>> angle = 0 [deg];
        }

        part :>> sailSystem : SailSystem {
            part :>> sail : Sail {
                attribute :>> area = 40 [m^2];
                attribute :>> material = "Dacron";
            }
            part :>> mast : Mast {
                attribute :>> height = 15 [m];
            }
            part :>> boom : Boom {
                attribute :>> length = 5 [m];
            }
            part :>> rigging : Rigging {
                attribute :>> maxTensileForce = 50000 [N];
            }
        }

        interface windInterface
            connect mySailboat.windPort to mySailboat.sailSystem.windPort;
        interface sailCmdInterface
            connect mySailboat.sailCmdPort to mySailboat.sailSystem.cmdPort;
        interface forceInterface
            connect mySailboat.sailSystem.forcePort to mySailboat.hull.forcePort;
        interface rudderCmdInterface
            connect mySailboat.rudderCmdPort to mySailboat.rudder.commandPort;
        interface rudderMountInterface
            connect mySailboat.rudder.hullAttachment to mySailboat.hull.rudderAttachment;
        interface stateInterface
            connect mySailboat.hull.vesselStatePort to mySailboat.vesselStatePort;
    }

    requirement <'1.1'> thrustReq : MinimumThrustRequirement {
        subject :>> sailboat = mySailboat;
        attribute :>> windSpeed = 10 [m/s];
        attribute :>> sailAngle = 45 [deg];
        attribute :>> minThrust = 500 [N];
    }

    requirement <'2.1'> windRangeReq : SafeWindSpeedRequirement {
        subject :>> sailboat = mySailboat;
        attribute :>> minWindSpeed = 2 [m/s];
        attribute :>> maxWindSpeed = 25 [m/s];
    }

    requirement <'3.1'> structReq : StructuralIntegrityRequirement {
        subject :>> rigging = mySailboat.sailSystem.rigging;
        attribute :>> maxTensileForce = 50000 [N];
    }

    requirement <'4.1'> heelReq : HeelAngleLimitRequirement {
        subject :>> sailboat = mySailboat;
        attribute :>> maxHeelAngle = 35 [deg];
    }
}
