package CurbFeelerSystemModel {

    import ScalarValues::*;
    import ISQ::*;

    attribute def Length :> ISQ::length;
    attribute def Force :> ISQ::force;
    attribute def Angle :> ISQ::planeAngle;
    attribute def Speed :> ISQ::speed;
    attribute def Duration :> ISQ::time;
    attribute def SoundPressureLevel;
    attribute def Voltage :> ISQ::electricPotential;
    attribute def Current :> ISQ::electricCurrent;

    enum def ContactState {
        enum noContact;
        enum lightContact;
        enum sustainedContact;
        enum excessiveDeflection;
    }

    enum def AlertMode {
        enum silent;
        enum tactile;
        enum audible;
        enum visual;
        enum combined;
    }

    item def MechanicalContactSignal {
        attribute contactForce : Force;
        attribute deflectionAngle : Angle;
        attribute contactDuration : Duration;
        attribute contactLocationHeight : Length;
        attribute state : ContactState;
    }

    item def DriverAlertSignal {
        attribute mode : AlertMode;
        attribute urgencyLevel : Integer;
        attribute message : String;
        attribute pulseRate : Frequency;
        attribute soundLevel : SoundPressureLevel;
    }

    item def MountingLoad {
        attribute lateralForce : Force;
        attribute bendingMoment : Torque;
        attribute vibrationLevel : Acceleration;
    }

    port def ContactSensingPort {
        out item contactSignal : MechanicalContactSignal;
    }

    port def AlertOutputPort {
        out item alertSignal : DriverAlertSignal;
    }

    port def MechanicalAttachmentPort {
        in item load : MountingLoad;
    }

    port def PowerPort {
        in attribute supplyVoltage : Voltage;
        in attribute supplyCurrent : Current;
    }

    part def CurbFeelerSystem {
        attribute nominalProbeLength : Length = 0.305 [m];
        attribute curbDetectionThreshold : Force = 1.5 [N];
        attribute maximumSafeDeflection : Angle = 35 [deg];
        attribute requiredResponseTime : Duration = 0.2 [s];

        port mount : MechanicalAttachmentPort;
        port power : PowerPort;
        port driverAlert : AlertOutputPort;

        part feelerAssembly : FlexibleFeelerAssembly;
        part contactInterpreter : ContactInterpreter;
        part alertController : AlertController;
        part driverInterface : DriverInterface;

        connect feelerAssembly.contactOutput to contactInterpreter.contactInput;
        connect contactInterpreter.alertDecisionOutput to alertController.alertDecisionInput;
        connect alertController.alertOutput to driverInterface.alertInput;
        connect driverInterface.driverAlertOutput to driverAlert;

        perform action detectCurbProximity;
        exhibit state curbFeelerOperationalStates;
    }

    part def FlexibleFeelerAssembly {
        attribute probeLength : Length = 0.305 [m];
        attribute probeDiameter : Length = 0.003 [m];
        attribute freeEndHeightAboveRoad : Length = 0.075 [m];
        attribute springStiffness : Force = 4.0 [N];
        attribute corrosionResistanceRating : Integer = 5;

        port attachment : MechanicalAttachmentPort;
        port contactOutput : ContactSensingPort;

        part mountingBracket : MountingBracket;
        part flexibleProbe : FlexibleProbe;
        part deflectionSensor : DeflectionSensor;

        connect flexibleProbe.mechanicalContact to deflectionSensor.sensedContact;
        connect deflectionSensor.contactOutput to contactOutput;
    }

    part def MountingBracket {
        attribute bracketMaterial : String = "stainless steel";
        attribute mountingHoleDiameter : Length = 0.006 [m];
        attribute lateralLoadCapacity : Force = 80 [N];

        port vehicleBodyInterface : MechanicalAttachmentPort;
    }

    part def FlexibleProbe {
        attribute material : String = "spring steel wire";
        attribute tipRadius : Length = 0.004 [m];
        attribute elasticRecoveryAngle : Angle = 45 [deg];
        attribute permanentDeformationLimit : Force = 15 [N];

        port mechanicalContact : ContactSensingPort;
    }

    part def DeflectionSensor {
        attribute minimumDetectableForce : Force = 0.5 [N];
        attribute maximumMeasuredDeflection : Angle = 50 [deg];
        attribute samplingPeriod : Duration = 0.02 [s];

        port sensedContact : ContactSensingPort;
        port contactOutput : ContactSensingPort;
    }

    part def ContactInterpreter {
        attribute lightContactThreshold : Force = 1.5 [N];
        attribute sustainedContactTime : Duration = 0.15 [s];
        attribute excessiveDeflectionThreshold : Angle = 35 [deg];

        port contactInput : ContactSensingPort;
        port alertDecisionOutput : AlertOutputPort;

        perform action classifyContact;
    }

    part def AlertController {
        attribute minimumAlertInterval : Duration = 0.25 [s];
        attribute audibleAlertLevel : SoundPressureLevel = 65;
        attribute tactilePulseRate : Frequency = 8 [Hz];

        port alertDecisionInput : AlertOutputPort;
        port alertOutput : AlertOutputPort;

        perform action generateDriverAlert;
    }

    part def DriverInterface {
        attribute supportsAudibleTone : Boolean = true;
        attribute supportsDashboardIndicator : Boolean = true;
        attribute supportsSeatVibration : Boolean = false;

        port alertInput : AlertOutputPort;
        port driverAlertOutput : AlertOutputPort;
    }

    action def detectCurbProximity {
        in item contact : MechanicalContactSignal;
        out item alert : DriverAlertSignal;

        first start;
        then evaluateContact;

        action evaluateContact {
            if contact.contactForce < 1.5 [N] then noAlert;
            else if contact.deflectionAngle > 35 [deg] then highUrgencyAlert;
            else curbProximityAlert;
        }

        action noAlert {
            out item alert = DriverAlertSignal {
                mode = AlertMode::silent;
                urgencyLevel = 0;
                message = "No curb contact detected";
                pulseRate = 0 [Hz];
                soundLevel = 0;
            };
        }

        action curbProximityAlert {
            out item alert = DriverAlertSignal {
                mode = AlertMode::audible;
                urgencyLevel = 2;
                message = "Curb proximity detected by feeler contact";
                pulseRate = 4 [Hz];
                soundLevel = 65;
            };
        }

        action highUrgencyAlert {
            out item alert = DriverAlertSignal {
                mode = AlertMode::combined;
                urgencyLevel = 4;
                message = "Curb contact force or deflection exceeds preferred limit";
                pulseRate = 8 [Hz];
                soundLevel = 72;
            };
        }

        then done;
    }

    action def classifyContact {
        in item sensedContact : MechanicalContactSignal;
        out item interpretedAlert : DriverAlertSignal;

        if sensedContact.state == ContactState::noContact then
            interpretedAlert.mode = AlertMode::silent;
        else if sensedContact.state == ContactState::lightContact then
            interpretedAlert.mode = AlertMode::audible;
        else if sensedContact.state == ContactState::sustainedContact then
            interpretedAlert.mode = AlertMode::combined;
        else
            interpretedAlert.mode = AlertMode::combined;
    }

    action def generateDriverAlert {
        in item interpretedAlert : DriverAlertSignal;
        out item driverAlert : DriverAlertSignal;

        driverAlert.mode = interpretedAlert.mode;
        driverAlert.urgencyLevel = interpretedAlert.urgencyLevel;
        driverAlert.message = interpretedAlert.message;
        driverAlert.pulseRate = interpretedAlert.pulseRate;
        driverAlert.soundLevel = interpretedAlert.soundLevel;
    }

    state def curbFeelerOperationalStates {
        entry action initializeSystem;

        state inactive;
        state monitoring;
        state curbContactDetected;
        state alertingDriver;
        state faultProtected;

        initial then inactive;

        transition inactive_to_monitoring
            first inactive
            accept PowerApplied
            then monitoring;

        transition monitoring_to_contact
            first monitoring
            accept ContactDetected
            if contactForce >= 1.5 [N]
            then curbContactDetected;

        transition contact_to_alert
            first curbContactDetected
            accept ContactClassified
            then alertingDriver;

        transition alert_to_monitoring
            first alertingDriver
            accept ContactCleared
            then monitoring;

        transition monitoring_to_fault
            first monitoring
            accept ExcessiveDeflection
            if deflectionAngle > 35 [deg]
            then faultProtected;

        transition fault_to_monitoring
            first faultProtected
            accept ProbeRecovered
            then monitoring;
    }

    action def initializeSystem {
        out attribute ready : Boolean = true;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : CurbFeelerSystem;

        doc /* The curb feeler system shall provide an early, high-level indication that a vehicle is close enough to a curb or similar low roadside obstacle for the flexible probe to touch it, allowing the driver to correct vehicle position before wheel, tire, or body damage occurs. */

        require constraint {
            system.requiredResponseTime <= 0.2 [s]
        }
    }

    requirement def ContactDetectionRequirement {
        subject assembly : FlexibleFeelerAssembly;

        doc /* The flexible feeler assembly shall detect lateral contact with a curb when the contact force at the probe tip is at least 1.5 newtons. */

        require constraint {
            assembly.deflectionSensor.minimumDetectableForce <= 1.5 [N]
        }
    }

    requirement def ElasticRecoveryRequirement {
        subject probe : FlexibleProbe;

        doc /* The probe shall elastically recover from curb contact deflections up to 35 degrees without permanent deformation. */

        require constraint {
            probe.elasticRecoveryAngle >= 35 [deg]
        }
    }

    requirement def DriverAlertRequirement {
        subject controller : AlertController;

        doc /* The alert controller shall issue an audible or combined alert when curb contact is classified as light, sustained, or excessive. */

        require constraint {
            controller.audibleAlertLevel >= 60
        }
    }

    requirement def MountingIntegrityRequirement {
        subject bracket : MountingBracket;

        doc /* The mounting bracket shall withstand normal curb feeler operating loads without detaching from the vehicle body. */

        require constraint {
            bracket.lateralLoadCapacity >= 80 [N]
        }
    }

    satisfy PrimaryFunctionRequirement by CurbFeelerSystem::detectCurbProximity;
    satisfy ContactDetectionRequirement by FlexibleFeelerAssembly::deflectionSensor;
    satisfy ElasticRecoveryRequirement by FlexibleProbe;
    satisfy DriverAlertRequirement by AlertController::generateDriverAlert;
    satisfy MountingIntegrityRequirement by MountingBracket;

    part curbFeelerInstallation : CurbFeelerSystem {
        attribute nominalProbeLength = 0.305 [m];
        attribute curbDetectionThreshold = 1.5 [N];
        attribute maximumSafeDeflection = 35 [deg];
        attribute requiredResponseTime = 0.2 [s];
    }
}