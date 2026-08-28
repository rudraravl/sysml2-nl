package AutomatedRectalDilatorSystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    attribute def Diameter :> ISQ::length;
    attribute def PressureValue :> ISQ::pressure;
    attribute def TimeValue :> ISQ::time;
    attribute def ForceValue :> ISQ::force;

    enum def ProcedureMode {
        gradual;
        rapid;
        manual;
    }

    item def TissuePressure {
        attribute value : PressureValue;
    }

    item def ExpansionCommand {
        attribute targetDiameter : Diameter;
        attribute stepSize : Diameter = 2 [SI::mm];
        attribute pauseDuration : TimeValue = 5 [SI::s];
        attribute mode : ProcedureMode;
    }

    item def AlarmSignal {
        attribute active : Boolean;
    }

    port def UserInputPort {
        in targetDiameter : Diameter;
        in mode : ProcedureMode;
    }

    port def PressureOutPort {
        out pressure : TissuePressure;
    }

    port def PressureInPort {
        in pressure : TissuePressure;
    }

    port def CommandOutPort {
        out command : ExpansionCommand;
    }

    port def CommandInPort {
        in command : ExpansionCommand;
    }

    port def AlarmOutPort {
        out alarm : AlarmSignal;
    }

    port def ForceOutPort {
        out force : ForceValue;
    }

    port def ForceInPort {
        in force : ForceValue;
    }

    action def PreUseChecks;
    action def LubricateAndPosition;
    action def ExpandStep;
    action def PauseAndMonitor;

    action def IncrementalDilation {
        action expandStep : ExpandStep;
        action pauseAndMonitor : PauseAndMonitor;
        first expandStep;
        then pauseAndMonitor;
        then done;
    }

    action def MaintainDiameter;
    action def ControlledRetraction;
    action def WithdrawDevice;
    action def EmergencyRetraction;
    action def TriggerAlarm;
    action def StartDilation;
    action def StopDilation;
    action def StartRetraction;

    action def ExecuteProcedure {
        action preUseChecks : PreUseChecks;
        action lubricateAndPosition : LubricateAndPosition;
        action incrementalExpansion : IncrementalDilation;
        action maintainDiameter : MaintainDiameter;
        action controlledRetraction : ControlledRetraction;
        action withdrawDevice : WithdrawDevice;
        first preUseChecks;
        then lubricateAndPosition;
        then incrementalExpansion;
        then maintainDiameter;
        then controlledRetraction;
        then withdrawDevice;
        then done;
    }

    part def DilatorTip {
        attribute material : String = "Medical Silicone";
        attribute shape : String = "Tapered";
        attribute taperAngle : Real = 15.0;
    }

    part def ExpandableShaft {
        attribute material : String = "Medical Silicone";
        attribute minDiameter : Diameter = 10 [SI::mm];
        attribute maxDiameter : Diameter = 40 [SI::mm];
        attribute currentDiameter : Diameter = 10 [SI::mm];
        port forceInPort : ForceInPort;
        port pressureOutPort : PressureOutPort;
        perform action expand {
            in targetDiameter : Diameter;
        }
        perform action retract;
    }

    part def ExpansionMechanism {
        port commandInPort : CommandInPort;
        port forceOutPort : ForceOutPort;
        perform action applyForce {
            in command : ExpansionCommand;
            out force : ForceValue;
        }
    }

    part def ControlModule {
        port userInputPort : UserInputPort;
        port pressureInPort : PressureInPort;
        port commandOutPort : CommandOutPort;
        attribute targetDiameter : Diameter;
        attribute procedureMode : ProcedureMode;
        attribute holdDuration : TimeValue = 300 [SI::s];
        attribute stepSize : Diameter = 2 [SI::mm];
        attribute pauseDuration : TimeValue = 5 [SI::s];
        perform action controlProcedure {
            in target : Diameter;
            in mode : ProcedureMode;
        }
    }

    part def PressureMonitor {
        port pressureInPort : PressureInPort;
        port alarmOutPort : AlarmOutPort;
        attribute currentPressure : PressureValue;
        attribute safeThreshold : PressureValue = 50 [SI::kPa];
        perform action monitorPressure {
            in pressure : TissuePressure;
            out alarm : AlarmSignal;
        }
    }

    part def SafetyRelease {
        port pressureInPort : PressureInPort;
        attribute criticalThreshold : PressureValue = 80 [SI::kPa];
        perform action releasePressure {
            in pressure : TissuePressure;
        }
    }

    state def SystemStates {
        attribute currentDiameter : Diameter;
        attribute targetDiameter : Diameter;
        attribute currentPressure : PressureValue;
        attribute safeThreshold : PressureValue;
        attribute criticalThreshold : PressureValue;
        attribute elapsedHoldTime : TimeValue;
        attribute holdDuration : TimeValue;

        state idle;
        state preparing {
            entry PreUseChecks;
        }
        state dilating {
            entry StartDilation;
            do IncrementalDilation;
            exit StopDilation;
        }
        state maintaining {
            entry MaintainDiameter;
        }
        state retracting {
            entry StartRetraction;
            do ControlledRetraction;
        }
        state complete {
            entry WithdrawDevice;
        }
        state emergency {
            entry TriggerAlarm;
            do EmergencyRetraction;
        }

        transition t1 from idle to preparing;
        transition t2 from preparing to dilating;
        transition t3 from dilating to maintaining if currentDiameter >= targetDiameter;
        transition t4 from maintaining to retracting if elapsedHoldTime >= holdDuration;
        transition t5 from retracting to complete;
        transition t6 from complete to idle;
        transition t7 from dilating to emergency if currentPressure > criticalThreshold;
        transition t8 from maintaining to emergency if currentPressure > criticalThreshold;
        transition t9 from emergency to retracting if currentPressure < safeThreshold;
    }

    part def RectalDilatorSystem {
        part dilatorTip : DilatorTip;
        part expandableShaft : ExpandableShaft;
        part expansionMechanism : ExpansionMechanism;
        part controlModule : ControlModule;
        part pressureMonitor : PressureMonitor;
        part safetyRelease : SafetyRelease;

        port userInputPort : UserInputPort;
        port alarmPort : AlarmOutPort;

        attribute elapsedHoldTime : TimeValue;

        bind userInputPort = controlModule.userInputPort;

        flow pressureToMonitorFlow of TissuePressure
            from expandableShaft.pressureOutPort.pressure
            to pressureMonitor.pressureInPort.pressure;

        flow pressureToControlFlow of TissuePressure
            from expandableShaft.pressureOutPort.pressure
            to controlModule.pressureInPort.pressure;

        flow pressureToSafetyFlow of TissuePressure
            from expandableShaft.pressureOutPort.pressure
            to safetyRelease.pressureInPort.pressure;

        flow commandFlow of ExpansionCommand
            from controlModule.commandOutPort.command
            to expansionMechanism.commandInPort.command;

        flow forceFlow of ForceValue
            from expansionMechanism.forceOutPort.force
            to expandableShaft.forceInPort.force;

        flow alarmFlow of AlarmSignal
            from pressureMonitor.alarmOutPort.alarm
            to alarmPort.alarm;

        perform action executeProcedure : ExecuteProcedure;
        perform action emergencyRetraction : EmergencyRetraction;

        exhibit state systemStates : SystemStates;
    }

    requirement def PatientSafetyRequirement {
        subject dilator : RectalDilatorSystem;
        doc /* The system must minimize patient discomfort and prevent tissue trauma. */
        require constraint {
            dilator.pressureMonitor.currentPressure <= dilator.pressureMonitor.safeThreshold
        }
    }

    requirement def OperationalRequirement {
        subject dilator : RectalDilatorSystem;
        doc /* The system shall perform controlled, gradual dilation from 10 mm to 40 mm. */
        require constraint {
            dilator.expandableShaft.minDiameter == 10 [SI::mm] and
            dilator.expandableShaft.maxDiameter == 40 [SI::mm]
        }
    }

    requirement def EmergencyResponseRequirement {
        subject dilator : RectalDilatorSystem;
        doc /* If pressure exceeds a critical threshold, the system shall perform emergency retraction. */
        require constraint {
            dilator.safetyRelease.criticalThreshold > dilator.pressureMonitor.safeThreshold
        }
    }

    requirement def BiocompatibilityRequirement {
        subject dilator : RectalDilatorSystem;
        doc /* The Dilator Tip and Expandable Shaft shall be made from biocompatible medical silicone. */
        require constraint {
            dilator.dilatorTip.material == "Medical Silicone" and
            dilator.expandableShaft.material == "Medical Silicone"
        }
    }

    part rectalDilatorSystem : RectalDilatorSystem;

    satisfy PatientSafetyRequirement by rectalDilatorSystem;
    satisfy OperationalRequirement by rectalDilatorSystem;
    satisfy EmergencyResponseRequirement by rectalDilatorSystem;
    satisfy BiocompatibilityRequirement by rectalDilatorSystem;
}
