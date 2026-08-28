package AutonomousRobotSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value def PowerLevel :> Real {
        unit 'W';
    }

    value def BatteryCharge :> Real {
        unit '%';
    }

    value def StructuralIntegrity :> Real {
        unit '%';
    }

    value def Distance :> Length;

    value def ThreatLevel :> Real {
        unit '1';
    }

    value def Confidence :> Real {
        unit '%';
    }

    value def Priority :> Integer;

    // ===== Enumerations =====

    enum def HazardKind {
        none;
        physicalObstacle;
        fallingObject;
        fire;
        electrical;
        chemical;
        humanProximity;
    }

    enum def CommandStatus {
        pending;
        validated;
        rejected;
        approved;
        executing;
        completed;
        failed;
    }

    enum def ActionKind {
        idle;
        move;
        halt;
        intervene;
        selfProtect;
        emergencyStop;
        report;
    }

    enum def AlertKind {
        nominal;
        caution;
        warning;
        critical;
    }

    // ===== Item Definitions =====

    item def HumanObservation {
        attribute detected : Boolean;
        attribute distance : Distance;
        attribute confidence : Confidence;
    }

    item def HazardObservation {
        attribute kind : HazardKind;
        attribute distance : Distance;
        attribute threat : ThreatLevel;
    }

    item def SelfCondition {
        attribute battery : BatteryCharge;
        attribute integrity : StructuralIntegrity;
        attribute power : PowerLevel;
    }

    item def PerceptionSnapshot {
        attribute humans : HumanObservation[0..*];
        attribute hazards : HazardObservation[0..*];
        attribute self : SelfCondition;
        attribute timestamp : Time;
    }

    item def HumanCommand {
        attribute id : String;
        attribute description : String;
        attribute issuedAt : Time;
        attribute status : CommandStatus := CommandStatus::pending;
    }

    item def ApprovedAction {
        attribute kind : ActionKind;
        attribute priority : Priority;
        attribute justification : String;
        attribute issuedAt : Time;
    }

    item def SafetyAlert {
        attribute kind : AlertKind;
        attribute threat : ThreatLevel;
        attribute requiresEmergencyStop : Boolean;
        attribute issuedAt : Time;
    }

    item def ExecutionReport {
        attribute actionKind : ActionKind;
        attribute success : Boolean;
        attribute completedAt : Time;
    }

    // ===== Port Definitions =====

    port def PerceptionOut {
        out snapshot : PerceptionSnapshot;
    }

    port def PerceptionIn {
        in snapshot : PerceptionSnapshot;
    }

    port def CommandIn {
        in command : HumanCommand;
    }

    port def CommandOut {
        out command : HumanCommand;
    }

    port def ActionOut {
        out action : ApprovedAction;
    }

    port def ActionIn {
        in action : ApprovedAction;
    }

    port def ReportOut {
        out report : ExecutionReport;
    }

    port def ReportIn {
        in report : ExecutionReport;
    }

    port def AlertOut {
        out alert : SafetyAlert;
    }

    port def AlertIn {
        in alert : SafetyAlert;
    }

    port def EmergencyStopOut {
        out stop : Boolean;
    }

    port def EmergencyStopIn {
        in stop : Boolean;
    }

    // ===== Perception System =====

    part def PerceptionSystem {
        port perceptionOut : PerceptionOut;
        port conditionOut : PerceptionOut;

        attribute scanInterval : Time = 0.1 [s];

        part environmentScanner {
            attribute range : Distance = 10.0 [m];
        }

        part selfMonitor {
            attribute battery : BatteryCharge = 100.0 [%];
            attribute integrity : StructuralIntegrity = 100.0 [%];
            attribute power : PowerLevel = 75.0 [W];
        }

        action def ScanEnvironment {
            in interval : Time;
            out snapshot : PerceptionSnapshot;
        }

        action def MonitorSelf {
            out condition : SelfCondition;
        }

        perform action scanLoop : ScanEnvironment {
            // continuously produces snapshots
        }

        perform action selfLoop : MonitorSelf {
            // continuously updates self condition
        }

        flow from scanLoop.snapshot to perceptionOut.snapshot;
        flow from selfLoop.condition to conditionOut.snapshot.self;
    }

    // ===== Command Interface =====

    part def CommandInterface {
        port commandIn : CommandIn;
        port commandOut : CommandOut;

        action def ValidateCommand {
            in command : HumanCommand;
            out validated : HumanCommand;
        }

        perform action validate : ValidateCommand;

        flow from commandIn.command to validate.command;
        flow from validate.validated to commandOut.command;
    }

    // ===== Ethics Core =====

    part def EthicsCore {
        port perceptionIn : PerceptionIn;
        port commandIn : CommandIn;
        port alertIn : AlertIn;
        port actionOut : ActionOut;
        port reportIn : ReportIn;

        attribute evaluationCycle : Time = 0.05 [s];

        state machine def EthicalDecisionMaking {

            state EvaluatingSafety;
            state ConsideringCommand;
            state ConsideringSelfPreservation;
            state Approved;
            state Rejected;
            state EmergencyHalt;

            transition t1 initial to EvaluatingSafety;
            transition t2 EvaluatingSafety to EmergencyHalt
                when alertIn.alert.requiresEmergencyStop == true;
            transition t3 EvaluatingSafety to ConsideringCommand
                when perceptionIn.snapshot.hazards->select(t | t.threat > 0.7 [1])->isEmpty()
                and alertIn.alert.kind != AlertKind::critical;
            transition t4 ConsideringCommand to Rejected
                when commandIn.command.status == CommandStatus::pending
                and violatesFirstLaw(commandIn.command, perceptionIn.snapshot);
            transition t5 ConsideringCommand to Approved
                when commandIn.command.status == CommandStatus::validated
                and not violatesFirstLaw(commandIn.command, perceptionIn.snapshot);
            transition t6 ConsideringCommand to ConsideringSelfPreservation
                when commandIn.command.status == CommandStatus::pending
                and perceptionIn.snapshot.self.battery < 20.0 [%];
            transition t7 ConsideringSelfPreservation to Approved
                when not endangersHuman(perceptionIn.snapshot)
                and not contradictsValidCommand(commandIn.command);
            transition t8 Approved to EvaluatingSafety
                when reportIn.report.success == true;
            transition t9 Rejected to EvaluatingSafety;
            transition t10 EmergencyHalt to EvaluatingSafety
                when alertIn.alert.kind == AlertKind::nominal;
        }

        perform state machine decision : EthicalDecisionMaking;

        action def EvaluateFirstLaw {
            in snapshot : PerceptionSnapshot;
            in alert : SafetyAlert;
            out safe : Boolean;
        }

        action def EvaluateSecondLaw {
            in command : HumanCommand;
            in snapshot : PerceptionSnapshot;
            out approved : Boolean;
        }

        action def EvaluateThirdLaw {
            in snapshot : PerceptionSnapshot;
            in command : HumanCommand;
            out protect : Boolean;
        }

        perform action firstLawCheck : EvaluateFirstLaw;
        perform action secondLawCheck : EvaluateSecondLaw;
        perform action thirdLawCheck : EvaluateThirdLaw;

        flow from perceptionIn.snapshot to firstLawCheck.snapshot;
        flow from alertIn.alert to firstLawCheck.alert;
        flow from commandIn.command to secondLawCheck.command;
        flow from perceptionIn.snapshot to secondLawCheck.snapshot;
        flow from perceptionIn.snapshot to thirdLawCheck.snapshot;
        flow from commandIn.command to thirdLawCheck.command;

        flow from firstLawCheck.safe to actionOut.action;
        flow from secondLawCheck.approved to actionOut.action;
        flow from thirdLawCheck.protect to actionOut.action;

        private def violatesFirstLaw(command : HumanCommand, snapshot : PerceptionSnapshot) : Boolean {
            return snapshot.hazards->exists(h | h.threat > 0.7 [1] and h.kind == HazardKind::humanProximity);
        }

        private def endangersHuman(snapshot : PerceptionSnapshot) : Boolean {
            return snapshot.hazards->exists(h | h.threat > 0.5 [1]);
        }

        private def contradictsValidCommand(command : HumanCommand) : Boolean {
            return command.status == CommandStatus::approved;
        }
    }

    // ===== Safety Monitor =====

    part def SafetyMonitor {
        port perceptionIn : PerceptionIn;
        port alertOut : AlertOut;
        port emergencyStopOut : EmergencyStopOut;

        attribute threshold : ThreatLevel = 0.8 [1];

        state machine def Monitoring {

            state Nominal;
            state Caution;
            state Warning;
            state Critical;
            state EmergencyStopEngaged;

            transition t1 initial to Nominal;
            transition t2 Nominal to Caution
                when perceptionIn.snapshot.hazards->exists(h | h.threat > 0.3 [1]);
            transition t3 Caution to Warning
                when perceptionIn.snapshot.hazards->exists(h | h.threat > 0.5 [1]);
            transition t4 Warning to Critical
                when perceptionIn.snapshot.hazards->exists(h | h.threat > 0.7 [1]);
            transition t5 Critical to EmergencyStopEngaged
                when perceptionIn.snapshot.hazards->exists(h | h.threat > 0.9 [1]);
            transition t6 EmergencyStopEngaged to Nominal
                when perceptionIn.snapshot.hazards->select(h | h.threat > 0.5 [1])->isEmpty();
            transition t7 Warning to Caution
                when perceptionIn.snapshot.hazards->select(h | h.threat > 0.5 [1])->isEmpty();
            transition t8 Caution to Nominal
                when perceptionIn.snapshot.hazards->select(h | h.threat > 0.3 [1])->isEmpty();
        }

        perform state machine monitor : Monitoring;

        action def AnalyzeThreats {
            in snapshot : PerceptionSnapshot;
            out alert : SafetyAlert;
            out stop : Boolean;
        }

        perform action analyze : AnalyzeThreats;

        flow from perceptionIn.snapshot to analyze.snapshot;
        flow from analyze.alert to alertOut.alert;
        flow from analyze.stop to emergencyStopOut.stop;
    }

    // ===== Action Executor =====

    part def ActionExecutor {
        port actionIn : ActionIn;
        port reportOut : ReportOut;
        port emergencyStopIn : EmergencyStopIn;

        attribute halted : Boolean = false;

        part actuatorAssembly {
            attribute maxSpeed : Speed = 2.0 [m/s];
        }

        action def ExecuteAction {
            in action : ApprovedAction;
            out report : ExecutionReport;
        }

        perform action execute : ExecuteAction;

        flow from actionIn.action to execute.action;
        flow from execute.report to reportOut.report;
    }

    // ===== Robot =====

    part def Robot {
        port externalCommandIn : CommandIn;
        port externalReportOut : ReportOut;

        part perception : PerceptionSystem;
        part commandInterface : CommandInterface;
        part ethicsCore : EthicsCore;
        part safetyMonitor : SafetyMonitor;
        part actionExecutor : ActionExecutor;

        // Command flow
        flow from externalCommandIn.command to commandInterface.commandIn.command;
        flow from commandInterface.commandOut.command to ethicsCore.commandIn.command;

        // Perception flow
        flow from perception.perceptionOut.snapshot to ethicsCore.perceptionIn.snapshot;
        flow from perception.perceptionOut.snapshot to safetyMonitor.perceptionIn.snapshot;

        // Safety alert flow
        flow from safetyMonitor.alertOut.alert to ethicsCore.alertIn.alert;

        // Emergency stop flow
        flow from safetyMonitor.emergencyStopOut.stop to actionExecutor.emergencyStopIn.stop;

        // Action flow
        flow from ethicsCore.actionOut.action to actionExecutor.actionIn.action;

        // Report flow
        flow from actionExecutor.reportOut.report to ethicsCore.reportIn.report;
        flow from actionExecutor.reportOut.report to externalReportOut.report;
    }

    // ===== Requirements =====

    requirement def ThreeLawsFramework {
        doc /* The robot shall be governed by the three laws of robotics in strict priority order. */
    }

    requirement def FirstLaw :> ThreeLawsFramework {
        doc /* The robot shall not harm a human, nor through inaction allow a human to come to harm. */
        subject robot : Robot;
        assume perception.perceptionOut.snapshot.humans->notEmpty();
        require robot.ethicsCore.firstLawCheck.safe == true
            when robot.safetyMonitor.alertOut.alert.kind != AlertKind::critical;
    }

    requirement def SecondLaw :> ThreeLawsFramework {
        doc /* The robot shall obey human commands except where such commands conflict with the first law. */
        subject robot : Robot;
        require robot.ethicsCore.secondLawCheck.approved == true
            when robot.commandInterface.commandOut.command.status == CommandStatus::validated
            and robot.ethicsCore.firstLawCheck.safe == true;
    }

    requirement def ThirdLaw :> ThreeLawsFramework {
        doc /* The robot shall protect its own existence as long as such protection does not conflict with the first or second law. */
        subject robot : Robot;
        require robot.ethicsCore.thirdLawCheck.protect == true
            when robot.perception.selfMonitor.battery < 20.0 [%]
            and robot.ethicsCore.firstLawCheck.safe == true
            and robot.ethicsCore.secondLawCheck.approved == false;
    }

    requirement def SafetyMonitorRequirement {
        doc /* The safety monitor shall detect critical threats and trigger an emergency stop. */
        subject monitor : SafetyMonitor;
        require monitor.emergencyStopOut.stop == true
            when monitor.perceptionIn.snapshot.hazards->exists(h | h.threat > 0.9 [1]);
    }

    requirement def ContinuousOperationRequirement {
        doc /* The robot shall continuously perceive, decide, and act in a closed loop. */
        subject robot : Robot;
        require robot.perception.scanLoop.isRunning == true
            and robot.ethicsCore.decision.isActive == true
            and robot.actionExecutor.execute.isRunning == true;
    }

    requirement threeLaws : ThreeLawsFramework;
    requirement firstLaw : FirstLaw;
    requirement secondLaw : SecondLaw;
    requirement thirdLaw : ThirdLaw;
    requirement safetyMonitorReq : SafetyMonitorRequirement;
    requirement continuousOperation : ContinuousOperationRequirement;

    // ===== Satisfaction =====

    satisfaction robotSatisfiesFirstLaw : FirstLaw {
        subject robotInstance : Robot;
    }

    satisfaction robotSatisfiesSecondLaw : SecondLaw {
        subject robotInstance : Robot;
    }

    satisfaction robotSatisfiesThirdLaw : ThirdLaw {
        subject robotInstance : Robot;
    }

    satisfaction monitorSatisfiesSafety : SafetyMonitorRequirement {
        subject monitorInstance : SafetyMonitor;
    }

}
