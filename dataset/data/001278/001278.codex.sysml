package TestLightModel {
    import ScalarValues::*;

    attribute def Voltage :> Real { unit = "V"; }
    attribute def Current :> Real { unit = "mA"; }
    attribute def Resistance :> Real { unit = "ohm"; }
    attribute def Power :> Real { unit = "mW"; }
    attribute def Time :> Real { unit = "s"; }
    attribute def LuminousIntensity :> Real { unit = "mcd"; }

    enum def CircuitCondition {
        enum unknown;
        enum noVoltage;
        enum liveVoltage;
        enum overload;
    }

    enum def IndicationMode {
        enum dark;
        enum steadyLight;
        enum warningFlash;
    }

    item def ElectricalPotential {
        attribute potential : Voltage;
    }

    item def TestCurrent {
        attribute current : Current;
    }

    item def VisualSignal {
        attribute mode : IndicationMode;
        attribute intensity : LuminousIntensity;
    }

    item def OperatorCommand {
        attribute probeApplied : Boolean;
        attribute resetRequested : Boolean;
    }

    port def ProbePort {
        in item sensedPotential : ElectricalPotential;
        out item limitedCurrent : TestCurrent;
    }

    port def ReturnPort {
        in item referencePotential : ElectricalPotential;
        out item returnCurrent : TestCurrent;
    }

    port def IndicatorPort {
        out item visibleSignal : VisualSignal;
    }

    port def OperatorPort {
        in item command : OperatorCommand;
        out item visibleSignal : VisualSignal;
    }

    part def ProbeTip {
        port probeContact : ProbePort;
        attribute contactResistance : Resistance = 0.2;
        attribute maximumSafeVoltage : Voltage = 600.0;
    }

    part def ReturnLead {
        port returnContact : ReturnPort;
        attribute conductorResistance : Resistance = 0.5;
        attribute maximumSafeCurrent : Current = 25.0;
    }

    part def CurrentLimiter {
        port input : ProbePort;
        port output : ReturnPort;
        attribute nominalResistance : Resistance = 33000.0;
        attribute maximumPowerDissipation : Power = 500.0;
    }

    part def LampIndicator {
        port lampOutput : IndicatorPort;
        attribute minimumVisibleCurrent : Current = 0.4;
        attribute nominalIntensity : LuminousIntensity = 1200.0;
        attribute responseTime : Time = 0.1;
    }

    part def InsulatedHandle {
        attribute dielectricWithstandVoltage : Voltage = 1000.0;
        attribute gripContaminationAllowed : Boolean = false;
    }

    connection def ElectricalSensePath {
        end probeEnd : ProbePort;
        end returnEnd : ReturnPort;
    }

    action def MeasurePotential {
        in item probePotential : ElectricalPotential;
        in item referencePotential : ElectricalPotential;
        out attribute measuredVoltage : Voltage;
    }

    action def LimitTestCurrent {
        in attribute measuredVoltage : Voltage;
        out item safeCurrent : TestCurrent;
    }

    action def ClassifyCircuit {
        in attribute measuredVoltage : Voltage;
        out attribute condition : CircuitCondition;
    }

    action def DriveVisualIndicator {
        in attribute condition : CircuitCondition;
        in item safeCurrent : TestCurrent;
        out item signal : VisualSignal;
    }

    action def PerformVoltageTest {
        in item probePotential : ElectricalPotential;
        in item referencePotential : ElectricalPotential;
        out item operatorSignal : VisualSignal;

        action measure : MeasurePotential;
        action limit : LimitTestCurrent;
        action classify : ClassifyCircuit;
        action indicate : DriveVisualIndicator;

        flow probePotential to measure.probePotential;
        flow referencePotential to measure.referencePotential;
        flow measure.measuredVoltage to limit.measuredVoltage;
        flow measure.measuredVoltage to classify.measuredVoltage;
        flow limit.safeCurrent to indicate.safeCurrent;
        flow classify.condition to indicate.condition;
        flow indicate.signal to operatorSignal;

        succession first measure then limit;
        succession first measure then classify;
        succession first limit then indicate;
        succession first classify then indicate;
    }

    state def TestLightStateMachine {
        in item command : OperatorCommand;
        in item signal : VisualSignal;

        state idle;
        state probing;
        state indicatingLive;
        state indicatingNoVoltage;
        state faultOverload;

        transition idle_to_probing
            first idle
            then probing
            if command.probeApplied;

        transition probing_to_live
            first probing
            then indicatingLive
            if signal.mode == IndicationMode::steadyLight;

        transition probing_to_no_voltage
            first probing
            then indicatingNoVoltage
            if signal.mode == IndicationMode::dark;

        transition probing_to_overload
            first probing
            then faultOverload
            if signal.mode == IndicationMode::warningFlash;

        transition live_to_idle
            first indicatingLive
            then idle
            if not command.probeApplied or command.resetRequested;

        transition no_voltage_to_idle
            first indicatingNoVoltage
            then idle
            if not command.probeApplied or command.resetRequested;

        transition overload_to_idle
            first faultOverload
            then idle
            if command.resetRequested;
    }

    part def TestLight {
        part probeTip : ProbeTip;
        part returnLead : ReturnLead;
        part currentLimiter : CurrentLimiter;
        part lampIndicator : LampIndicator;
        part insulatedHandle : InsulatedHandle;

        port testProbe : ProbePort;
        port returnClip : ReturnPort;
        port operatorInterface : OperatorPort;
        port indication : IndicatorPort;

        attribute ratedMaximumVoltage : Voltage = 600.0;
        attribute minimumDetectableVoltage : Voltage = 24.0;
        attribute nominalTestCurrentAt120V : Current = 3.6;
        attribute energizedThreshold : Voltage = 24.0;
        attribute overloadThreshold : Voltage = 600.0;

        connection probe_to_limiter : ElectricalSensePath
            connect testProbe to currentLimiter.input;

        connection limiter_to_return : ElectricalSensePath
            connect currentLimiter.output to returnClip;

        flow lampIndicator.lampOutput.visibleSignal to indication.visibleSignal;
        flow indication.visibleSignal to operatorInterface.visibleSignal;

        perform action voltageTest : PerformVoltageTest {
            in probePotential = testProbe.sensedPotential;
            in referencePotential = returnClip.referencePotential;
            out operatorSignal = indication.visibleSignal;
        }

        exhibit state behavior : TestLightStateMachine;
    }

    part def CircuitUnderTest {
        port accessibleNode : ProbePort;
        port referenceNode : ReturnPort;
        attribute nodeVoltage : Voltage;
        attribute sourceAvailable : Boolean;
    }

    part def Operator {
        port handInterface : OperatorPort;
    }

    part def TestLightUseContext {
        part testLight : TestLight;
        part circuitUnderTest : CircuitUnderTest;
        part operator : Operator;

        connection probe_contact
            connect testLight.testProbe to circuitUnderTest.accessibleNode;

        connection return_contact
            connect testLight.returnClip to circuitUnderTest.referenceNode;

        connection operator_observation
            connect testLight.operatorInterface to operator.handInterface;
    }

    requirement def PrimaryFunctionRequirement {
        subject testLight : TestLight;

        require constraint {
            testLight.minimumDetectableVoltage <= 24.0 and
            testLight.ratedMaximumVoltage >= 600.0
        }

        doc
        /*
         * The test light shall provide a high-level indication of whether
         * an electrical circuit node is energized by conducting a limited
         * test current through an internal indicator and presenting a visible
         * light signal to the operator.
         */
    }

    requirement def CurrentLimitingRequirement {
        subject testLight : TestLight;

        require constraint {
            testLight.nominalTestCurrentAt120V <= 5.0
        }
    }

    requirement def VisibleIndicationRequirement {
        subject indicator : LampIndicator;

        require constraint {
            indicator.minimumVisibleCurrent <= 0.4 and
            indicator.responseTime <= 0.2
        }
    }

    requirement def InsulationRequirement {
        subject handle : InsulatedHandle;

        require constraint {
            handle.dielectricWithstandVoltage >= 1000.0 and
            handle.gripContaminationAllowed == false
        }
    }

    requirement def OverloadWarningRequirement {
        subject testLight : TestLight;

        require constraint {
            testLight.overloadThreshold == testLight.ratedMaximumVoltage
        }
    }

    satisfy PrimaryFunctionRequirement by TestLight;
    satisfy CurrentLimitingRequirement by CurrentLimiter;
    satisfy VisibleIndicationRequirement by LampIndicator;
    satisfy InsulationRequirement by InsulatedHandle;
    satisfy OverloadWarningRequirement by TestLight;

    part testLightSystem : TestLightUseContext;
}