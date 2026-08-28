package BronchialBlockerSystemModel {
    private import ScalarValues::*;
    private import ISQ::*;

    item def AirFlow;
    item def VisualFeed;

    value def PressureValue :> Real;
    value def OxygenSaturationValue :> Real;
    value def LengthValue :> Real;

    attribute def 'Insert Command';
    attribute def 'Positioning Complete';
    attribute def 'Placement Confirmed';
    attribute def 'Placement Misplaced';
    attribute def 'Adjustment Complete';
    attribute def 'Inflate Command';
    attribute def 'Inflation Complete';
    attribute def 'Deflate Command';
    attribute def 'High Pressure Alert';
    attribute def 'Procedure Complete';
    attribute def 'Deflation Complete';

    port def AirFlowPort {
        in airIn : AirFlow;
        out airOut : AirFlow;
    }
    port def PressurePort {
        out pressure : PressureValue;
    }
    port def OpticalPort {
        in visualIn : VisualFeed;
        out visualOut : VisualFeed;
    }
    port def OxygenPort {
        out oxygenSat : OxygenSaturationValue;
    }

    part def Patient {
        part airway {
            port airFlowPort : AirFlowPort;
            port opticalPort : OpticalPort;
        }
        part lungs {
            port oxygenPort : OxygenPort;
        }
    }

    part def InflatableCuff {
        port pressurePort : PressurePort;
        attribute is_inflated : Boolean = false;
        attribute cuffPressure : PressureValue;
    }

    part def FiberopticChannel {
        port opticalPort : OpticalPort;
    }

    part def PressureSensor {
        port pressurePort : PressurePort;
        attribute max_pressure : PressureValue = 30;
    }

    part def OxygenSensor {
        port oxygenPort : OxygenPort;
        attribute min_saturation : OxygenSaturationValue = 90;
    }

    part def BlockerCatheter {
        part inflatableCuff : InflatableCuff;
        part fiberopticChannel : FiberopticChannel;
        part pressureSensor : PressureSensor;

        port airwayAirFlowPort : AirFlowPort;
        port airwayOpticalPort : OpticalPort;
        port cuffPressurePort : PressurePort;
    }

    part def BronchialBlockerSystem {
        part blockerCatheter : BlockerCatheter;
        part oxygenSensor : OxygenSensor;

        port patientAirFlowPort : AirFlowPort;
        port patientOxygenPort : OxygenPort;

        perform action 'monitor status' : 'Monitor Status';
        exhibit state 'blocker states' : 'Blocker States';
    }

    action def 'Insert and Position';
    action def 'Verify Placement';
    action def 'Adjust Placement';
    action def 'Inflate Cuff';
    action def 'Deflate Cuff';
    action def 'Monitor Status' {
        in cuffPressure : PressureValue;
        in oxygenSaturation : OxygenSaturationValue;
    }

    state def 'Blocker States';

    requirement def 'Single Lung Ventilation' {
        doc /* The system must enable single-lung ventilation by isolating one lung using an inflatable cuff. */
        subject blockerSystem : BronchialBlockerSystem;
        constraint { blockerSystem.blockerCatheter.inflatableCuff.is_inflated == true }
    }

    requirement def 'Safe Cuff Pressure' {
        doc /* The pressure within the inflatable cuff must not exceed a safe maximum to prevent tissue damage. */
        subject cuff : InflatableCuff;
        attribute maxSafePressure : PressureValue = 30;
        constraint { cuff.cuffPressure <= maxSafePressure }
    }

    requirement def 'Continuous Monitoring' {
        doc /* The system must continuously monitor cuff pressure and patient oxygen saturation during the procedure. */
        subject blockerSystem : BronchialBlockerSystem;
        constraint { blockerSystem.oxygenSensor.min_saturation >= 90 }
    }

    action 'insert and position' : 'Insert and Position';
    action 'verify placement' : 'Verify Placement';
    action 'adjust placement' : 'Adjust Placement';
    action 'inflate cuff' : 'Inflate Cuff';
    action 'deflate cuff' : 'Deflate Cuff';
    action 'monitor status' : 'Monitor Status';

    part blockerSystem : BronchialBlockerSystem {
        part catheter : BlockerCatheter {
            part cuff : InflatableCuff;
            part channel : FiberopticChannel;
            part sensor : PressureSensor;
        }
        part o2Sensor : OxygenSensor;

        ref patient : Patient;

        connect catheter.airwayAirFlowPort to patient.airway.airFlowPort;
        connect catheter.airwayOpticalPort to patient.airway.opticalPort;
        connect catheter.cuffPressurePort to catheter.sensor.pressurePort;
        connect patient.lungs.oxygenPort to o2Sensor.oxygenPort;
    }

    state 'blocker states' : 'Blocker States' {
        entry; then idle;
        state idle;
        accept 'Insert Command' then inserting;
        state inserting {
            do 'insert and position';
        }
        accept 'Positioning Complete' then positioning;
        state positioning {
            do 'verify placement';
        }
        accept 'Placement Confirmed' then ready;
        accept 'Placement Misplaced' then adjusting;
        state adjusting {
            do 'adjust placement';
        }
        accept 'Adjustment Complete' then positioning;
        state ready;
        accept 'Inflate Command' then inflating;
        state inflating {
            do 'inflate cuff';
        }
        accept 'Inflation Complete' then inflated;
        state inflated {
            do 'monitor status';
        }
        accept 'Deflate Command' then deflating;
        accept 'High Pressure Alert' then deflating;
        accept 'Procedure Complete' then deflating;
        state deflating {
            do 'deflate cuff';
        }
        accept 'Deflation Complete' then idle;
    }

    requirement singleLungVentReq : 'Single Lung Ventilation';
    requirement safeCuffPressureReq : 'Safe Cuff Pressure';
    requirement continuousMonitoringReq : 'Continuous Monitoring';

    satisfy singleLungVentReq by blockerSystem;
    satisfy safeCuffPressureReq by blockerSystem.catheter.cuff;
    satisfy continuousMonitoringReq by blockerSystem.o2Sensor;
}
