package NanoneedleSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def LengthValue :> Real {
        unit = SI::metre;
    }

    attribute def ForceValue :> Real {
        unit = SI::newton;
    }

    attribute def VoltageValue :> Real {
        unit = SI::volt;
    }

    attribute def CurrentValue :> Real {
        unit = SI::ampere;
    }

    attribute def TimeValue :> Real {
        unit = SI::second;
    }

    attribute def ConcentrationValue :> Real {
        unit = SI::molePerCubicMetre;
    }

    attribute def FlowRateValue :> Real {
        unit = SI::cubicMetrePerSecond;
    }

    attribute def TemperatureValue :> Real {
        unit = SI::kelvin;
    }

    attribute def CountValue :> Integer;

    item def BioSample {
        attribute sampleVolume : LengthValue;
        attribute targetAnalyteConcentration : ConcentrationValue;
        attribute temperature : TemperatureValue;
    }

    item def TherapeuticPayload {
        attribute payloadConcentration : ConcentrationValue;
        attribute payloadVolume : LengthValue;
        attribute sterilityMaintained : Boolean;
    }

    item def SensorSignal {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute sampleTime : TimeValue;
    }

    item def ControlCommand {
        attribute insertionDepthSetpoint : LengthValue;
        attribute forceLimit : ForceValue;
        attribute deliveryFlowRate : FlowRateValue;
        attribute enableDelivery : Boolean;
    }

    item def PenetrationStatus {
        attribute inserted : Boolean;
        attribute measuredDepth : LengthValue;
        attribute measuredForce : ForceValue;
        attribute tissueContactDetected : Boolean;
    }

    port def SampleInterfacePort {
        in item sample : BioSample;
        out item status : PenetrationStatus;
    }

    port def PayloadPort {
        in item payload : TherapeuticPayload;
    }

    port def SignalPort {
        out item signal : SensorSignal;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    part def NanoneedleTip {
        attribute tipRadius : LengthValue = 50.0e-9;
        attribute shaftLength : LengthValue = 20.0e-6;
        attribute coatingThickness : LengthValue = 15.0e-9;
        attribute maximumAxialForce : ForceValue = 5.0e-6;

        port tissueInterface : SampleInterfacePort;
        port payloadInlet : PayloadPort;
        port electrochemicalSignal : SignalPort;
    }

    part def MicroActuator {
        attribute travelRange : LengthValue = 100.0e-6;
        attribute positioningResolution : LengthValue = 10.0e-9;
        attribute peakInsertionForce : ForceValue = 10.0e-6;

        port commandInput : CommandPort;
        port mechanicalOutput : SampleInterfacePort;
    }

    part def PayloadReservoir {
        attribute reservoirCapacity : LengthValue = 2.0e-9;
        attribute nominalFlowRate : FlowRateValue = 1.0e-12;
        attribute minimumDeliverableVolume : LengthValue = 1.0e-12;

        port payloadOutlet : PayloadPort;
    }

    part def BiosensorElectronics {
        attribute measurementVoltage : VoltageValue = 0.7;
        attribute leakageCurrentLimit : CurrentValue = 10.0e-9;
        attribute samplingPeriod : TimeValue = 0.01;

        port sensorInput : SignalPort;
    }

    part def ControlUnit {
        attribute insertionDepthTarget : LengthValue = 10.0e-6;
        attribute insertionForceLimit : ForceValue = 3.0e-6;
        attribute commandUpdatePeriod : TimeValue = 0.005;

        port actuatorCommand : CommandPort;
        port sensorFeedback : SignalPort;
    }

    part def SterileHousing {
        attribute housingLength : LengthValue = 5.0e-3;
        attribute maximumOperatingTemperature : TemperatureValue = 310.15;
        attribute sterileBarrierIntact : Boolean = true;
    }

    part def NanoneedleSystem {
        attribute primaryFunction : String = "Penetrate a biological sample at nanoscale dimensions to sense local biochemical conditions and deliver a controlled microscopic payload with minimal tissue disruption.";

        part needleTip : NanoneedleTip;
        part actuator : MicroActuator;
        part reservoir : PayloadReservoir;
        part electronics : BiosensorElectronics;
        part controller : ControlUnit;
        part housing : SterileHousing;

        port externalSampleInterface : SampleInterfacePort;

        connect reservoir.payloadOutlet to needleTip.payloadInlet;
        connect needleTip.electrochemicalSignal to electronics.sensorInput;
        connect electronics.sensorInput to controller.sensorFeedback;
        connect controller.actuatorCommand to actuator.commandInput;
        connect actuator.mechanicalOutput to needleTip.tissueInterface;
        connect needleTip.tissueInterface to externalSampleInterface;
    }

    action def InitializeNanoneedle {
        in part system : NanoneedleSystem;
        out attribute ready : Boolean;

        first start;
        then verifySterileBarrier;
        then zeroActuator;
        then calibrateSensor;
        then readyState;
        then done;

        action verifySterileBarrier {
            out attribute barrierOk : Boolean;
        }

        action zeroActuator {
            out attribute actuatorZeroed : Boolean;
        }

        action calibrateSensor {
            out attribute sensorCalibrated : Boolean;
        }

        action readyState {
            in attribute barrierOk : Boolean;
            in attribute actuatorZeroed : Boolean;
            in attribute sensorCalibrated : Boolean;
            out attribute ready : Boolean;
        }
    }

    action def PerformNanoneedleProcedure {
        in part system : NanoneedleSystem;
        in item command : ControlCommand;
        in item sample : BioSample;
        in item payload : TherapeuticPayload;
        out item status : PenetrationStatus;
        out item signal : SensorSignal;

        first receiveCommand;
        then approachSample;
        then detectContact;
        then insertNeedle;
        then acquireSignal;
        then deliverPayload;
        then retractNeedle;
        then reportStatus;
        then done;

        action receiveCommand {
            in item command : ControlCommand;
        }

        action approachSample {
            in item sample : BioSample;
            out attribute distanceToSurface : LengthValue;
        }

        action detectContact {
            out attribute contactDetected : Boolean;
            out attribute contactForce : ForceValue;
        }

        action insertNeedle {
            in attribute depthSetpoint : LengthValue;
            in attribute forceLimit : ForceValue;
            out item status : PenetrationStatus;
        }

        action acquireSignal {
            out item signal : SensorSignal;
        }

        action deliverPayload {
            in item payload : TherapeuticPayload;
            in attribute enableDelivery : Boolean;
            in attribute flowRate : FlowRateValue;
            out attribute delivered : Boolean;
        }

        action retractNeedle {
            out attribute retracted : Boolean;
        }

        action reportStatus {
            in item status : PenetrationStatus;
            in item signal : SensorSignal;
        }
    }

    state def NanoneedleOperationalState {
        entry action InitializeNanoneedle;

        state Idle;
        state Calibrating;
        state Ready;
        state ApproachingSample;
        state Inserting;
        state Measuring;
        state DeliveringPayload;
        state Retracting;
        state Complete;
        state Fault;

        transition first Idle;
        transition Idle_to_Calibrating
            first Idle
            then Calibrating;

        transition Calibrating_to_Ready
            first Calibrating
            accept done
            then Ready;

        transition Ready_to_Approaching
            first Ready
            accept ControlCommand
            then ApproachingSample;

        transition Approaching_to_Inserting
            first ApproachingSample
            accept PenetrationStatus
            if tissueContactDetected
            then Inserting;

        transition Inserting_to_Measuring
            first Inserting
            accept PenetrationStatus
            if inserted
            then Measuring;

        transition Measuring_to_Delivering
            first Measuring
            accept SensorSignal
            then DeliveringPayload;

        transition Delivering_to_Retracting
            first DeliveringPayload
            accept done
            then Retracting;

        transition Retracting_to_Complete
            first Retracting
            accept PenetrationStatus
            if not inserted
            then Complete;

        transition Any_to_Fault
            first Idle
            then Fault;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : NanoneedleSystem;

        doc
        /* The nanoneedle system shall provide controlled nanoscale access to a biological sample for localized sensing and optional payload delivery while minimizing mechanical disturbance. */

        require constraint {
            system.needleTip.tipRadius <= 100.0e-9
        }
    }

    requirement def InsertionDepthRequirement {
        subject system : NanoneedleSystem;

        doc
        /* The system shall control insertion depth with nanometre-scale resolution. */

        require constraint {
            system.actuator.positioningResolution <= 20.0e-9
        }
    }

    requirement def ForceLimitingRequirement {
        subject system : NanoneedleSystem;

        doc
        /* The system shall limit axial insertion force to reduce sample damage. */

        require constraint {
            system.controller.insertionForceLimit <= system.needleTip.maximumAxialForce
        }
    }

    requirement def PayloadDeliveryRequirement {
        subject system : NanoneedleSystem;

        doc
        /* The system shall deliver a controlled microscopic therapeutic or analytical payload through the nanoneedle tip when commanded. */

        require constraint {
            system.reservoir.nominalFlowRate > 0.0
        }
    }

    requirement def SensingRequirement {
        subject system : NanoneedleSystem;

        doc
        /* The system shall produce an electrical sensor signal representing local biochemical conditions at the nanoneedle tip. */

        require constraint {
            system.electronics.samplingPeriod <= 0.1
        }
    }

    requirement def SterilityRequirement {
        subject system : NanoneedleSystem;

        doc
        /* The system shall maintain a sterile barrier around all sample-contacting components before insertion. */

        require constraint {
            system.housing.sterileBarrierIntact == true
        }
    }

    satisfy PrimaryFunctionRequirement by NanoneedleSystem;
    satisfy InsertionDepthRequirement by MicroActuator;
    satisfy ForceLimitingRequirement by ControlUnit;
    satisfy PayloadDeliveryRequirement by PayloadReservoir;
    satisfy SensingRequirement by BiosensorElectronics;
    satisfy SterilityRequirement by SterileHousing;
}