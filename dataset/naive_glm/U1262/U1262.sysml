package WolfAutomatedWeldingCell {
    import ScalarValues::*;

    package Units {
        unit mm;
        unit m;
        unit s;
        unit min;
        unit A;
        unit V;
        unit L;
        unit deg;
        unit kg;
        unit percent;
        unit bar;
        unit mm_per_s;
        unit L_per_min;
        unit N;
    }

    package ValueTypes {
        value type LengthValue :> Real {
            :>> unit = mm;
        }
        value type VoltageValue :> Real {
            :>> unit = V;
        }
        value type CurrentValue :> Real {
            :>> unit = A;
        }
        value type TravelSpeedValue :> Real {
            :>> unit = mm_per_s;
        }
        value type WireFeedSpeedValue :> Real {
            :>> unit = mm_per_s;
        }
        value type GasFlowRateValue :> Real {
            :>> unit = L_per_min;
        }
        value type AngleValue :> Real {
            :>> unit = deg;
        }
        value type MassValue :> Real {
            :>> unit = kg;
        }
        value type QualityScoreValue :> Real {
            :>> unit = percent;
        }
        value type PressureValue :> Real {
            :>> unit = bar;
        }
        value type BeadWidthValue :> Real {
            :>> unit = mm;
        }
        value type BeadHeightValue :> Real {
            :>> unit = mm;
        }
        value type PenetrationValue :> Real {
            :>> unit = mm;
        }
        value type TemperatureValue :> Real;
        value type ForceValue :> Real {
            :>> unit = N;
        }
    }

    package ItemTypes {
        item def SeamGeometry {
            attribute startPoint : LengthValue[3];
            attribute endPoint : LengthValue[3];
            attribute seamLength : LengthValue;
            attribute seamType : String;
            attribute root opening : LengthValue;
        }

        item def Workpiece {
            attribute partId : String;
            attribute material : String;
            attribute thickness : LengthValue;
            attribute width : LengthValue;
            attribute height : LengthValue;
            attribute seam : SeamGeometry;
        }

        item def WeldingWire {
            attribute diameter : LengthValue;
            attribute material : String;
            attribute remainingLength : LengthValue;
            attribute spoolMass : MassValue;
        }

        item def ShieldingGas {
            attribute mixture : String;
            attribute tankPressure : PressureValue;
            attribute tankCapacity : Real;
        }

        item def WeldBead {
            attribute beadWidth : BeadWidthValue;
            attribute beadHeight : BeadHeightValue;
            attribute penetration : PenetrationValue;
            attribute qualityScore : QualityScoreValue;
            attribute beadLength : LengthValue;
            attribute surfaceRoughness : Real;
        }

        item def WeldDefect {
            attribute defectType : String;
            attribute location : LengthValue[3];
            attribute severity : QualityScoreValue;
            attribute defectLength : LengthValue;
        }

        item def ScanData {
            attribute seamGeometry : SeamGeometry;
            attribute surfaceFeatures : String;
            attribute timestamp : String;
            attribute pointCloudResolution : LengthValue;
        }

        item def WeldPathPlan {
            attribute waypoints : LengthValue[3][*];
            attribute targetCurrent : CurrentValue;
            attribute targetVoltage : VoltageValue;
            attribute targetTravelSpeed : TravelSpeedValue;
            attribute targetWireFeedSpeed : WireFeedSpeedValue;
            attribute targetGasFlowRate : GasFlowRateValue;
            attribute torchAngle : AngleValue;
        }

        item def QualityReport {
            attribute bead : WeldBead;
            attribute defects : WeldDefect[*];
            attribute overallQuality : QualityScoreValue;
            attribute pass : Boolean;
            attribute timestamp : String;
        }

        item def ElectricPower {
            attribute current : CurrentValue;
            attribute voltage : VoltageValue;
        }

        item def JointCommand {
            attribute jointPositions : AngleValue[6];
            attribute velocity : TravelSpeedValue;
            attribute acceleration : Real;
        }
    }

    package PortDefinitions {
        port def ControlPort {
            in command : String;
            in parameterValue : Real;
            out status : String;
            out telemetry : String;
        }

        port def DataPort {
            in dataIn : String;
            out dataOut : String;
        }

        port def ImagePort {
            out image : String;
            out imageMetadata : String;
        }

        port def PowerPort {
            out power : ElectricPower;
        }

        port def WirePort {
            out wire : WeldingWire;
        }

        port def GasPort {
            out gas : ShieldingGas;
            out flowRate : GasFlowRateValue;
        }

        port def SafetyPort {
            out emergencyStop : Boolean;
            out doorStatus : String;
            out lightCurtainStatus : Boolean;
        }
    }

    package ComponentDefinitions {
        part def Joint {
            attribute jointId : Integer;
            attribute currentAngle : AngleValue;
            attribute minAngle : AngleValue;
            attribute maxAngle : AngleValue;
            attribute maxTorque : ForceValue;
            attribute configured : Boolean = false;
        }

        part def RoboticArm {
            attribute numJoints : Integer = 6;
            attribute maxReach : LengthValue = 2000;
            attribute payloadCapacity : MassValue = 20;
            attribute repeatability : LengthValue = 0.05;
            attribute jointAngles : AngleValue[6];
            attribute currentPose : LengthValue[3];
            attribute weldPassComplete : Boolean = false;
            attribute currentTravelSpeed : TravelSpeedValue;

            port controlPort : ControlPort;

            part joints : Joint[6];

            action moveToPosition(in targetPosition : LengthValue[3], in speed : TravelSpeedValue) {
                /* Compute inverse kinematics and drive joints to target */
            }

            action followPath(in pathPlan : WeldPathPlan) {
                /* Execute continuous motion along all waypoints in the path plan */
            }

            action setTravelSpeed(in speed : TravelSpeedValue) {
                /* Override current travel speed during execution */
            }

            action homeAllJoints() {
                /* Return all joints to zero position */
            }
        }

        part def WeldingTorch {
            attribute torchType : String = "MIG/MAG";
            attribute nozzleDiameter : LengthValue = 15;
            attribute contactTipDiameter : LengthValue = 1.2;
            attribute stickOutLength : LengthValue = 12;
            attribute arcStruck : Boolean = false;
            attribute operatingTemperature : TemperatureValue;

            port powerInput : PowerPort;
            port wireInput : WirePort;
            port gasInput : GasPort;
            port controlPort : ControlPort;

            action strikeArc() {
                /* Initiate arc by contacting wire tip to workpiece then retracting */
            }

            action extinguishArc() {
                /* Terminate arc and perform crater fill */
            }

            action depositWeld(in pathPlan : WeldPathPlan, out bead : WeldBead) {
                /* Deposit filler material along the path producing a weld bead */
            }

            action purgeGas(in duration : Real) {
                /* Pre-flow gas to purge torch nozzle before arc strike */
            }
        }

        part def PowerSupply {
            attribute maxCurrent : CurrentValue = 600;
            attribute maxVoltage : VoltageValue = 50;
            attribute outputCurrent : CurrentValue;
            attribute outputVoltage : VoltageValue;
            attribute powerOn : Boolean = false;
            attribute dutyCycle : Real = 60;

            port powerOutput : PowerPort;
            port controlPort : ControlPort;

            action setOutput(in current : CurrentValue, in voltage : VoltageValue) {
                /* Configure constant-voltage or constant-current output */
            }

            action powerOff() {
                /* Disable all power output immediately */
            }

            action powerOn_() {
                /* Enable power supply and run self-test */
            }
        }

        part def WireFeedUnit {
            attribute feedSpeed : WireFeedSpeedValue;
            attribute maxFeedSpeed : WireFeedSpeedValue = 20000;
            attribute minFeedSpeed : WireFeedSpeedValue = 500;
            attribute wireLoaded : Boolean = false;
            attribute tensionSetting : Real;

            port wireInput : WirePort;
            port wireOutput : WirePort;
            port controlPort : ControlPort;

            action feedWire(in speed : WireFeedSpeedValue) {
                /* Drive feed rollers to supply wire at commanded rate */
            }

            action stopFeed() {
                /* Halt wire feed and brake rollers */
            }

            action loadWire(in wire : WeldingWire) {
                /* Thread new wire spool through drive rollers */
            }
        }

        part def WireSpool {
            attribute spoolId : String;
            attribute totalCapacity : LengthValue = 15000;
            attribute remaining : LengthValue;
            attribute spoolDiameter : LengthValue = 300;
            attribute coreDiameter : LengthValue = 52;
            attribute wire : WeldingWire;

            port wireOutput : WirePort;

            action dispenseWire(out lengthDispensed : LengthValue) {
                /* Release wire from spool and update remaining quantity */
            }
        }

        part def ShieldingGasSupply {
            attribute gasType : ShieldingGas;
            attribute tankPressure : PressureValue;
            attribute regulatorPressure : PressureValue;
            attribute currentFlowRate : GasFlowRateValue;
            attribute tankCapacity : Real = 50;
            attribute remainingVolume : Real;

            port gasOutput : GasPort;
            port controlPort : ControlPort;

            action setFlowRate(in rate : GasFlowRateValue) {
                /* Adjust regulator to achieve desired flow rate */
            }

            action stopFlow() {
                /* Close solenoid valve to stop gas flow */
            }

            action startFlow(in rate : GasFlowRateValue) {
                /* Open solenoid valve and set initial flow rate */
            }

            action checkTankLevel(out level : Real) {
                /* Report remaining gas volume */
            }
        }

        part def SystemController {
            attribute firmwareVersion : String = "WolfCtrl v2.4";
            attribute ipAddress : String;
            attribute status : String = "Offline";
            attribute pathPlanned : Boolean = false;
            attribute currentPathPlan : WeldPathPlan;
            attribute qualityReport : QualityReport;
            attribute reworkAttempts : Integer = 0;
            attribute maxReworkAttempts : Integer = 2;
            attribute adaptiveControlEnabled : Boolean = true;
            attribute responseTime : Real = 0.1;

            port robotControl : ControlPort;
            port torchControl : ControlPort;
            port powerControl : ControlPort;
            port wireFeedControl : ControlPort;
            port gasControl : ControlPort;
            port visionData : DataPort;

            action planWeldPath(in scanData : ScanData, out pathPlan : WeldPathPlan) {
                /* Compute optimal robot waypoints and initial welding parameters from scan */
            }

            action adjustParameters(in defect : WeldDefect, in currentPlan : WeldPathPlan, out adjustedPlan : WeldPathPlan) {
                /* Recompose target current, voltage, travel speed, and wire feed to correct defect */
            }

            action evaluateQuality(in bead : WeldBead, in defects : WeldDefect[*], out report : QualityReport) {
                /* Aggregate bead metrics and defect list into pass/fail quality report */
            }

            action coordinateMotion(in pathPlan : WeldPathPlan) {
                /* Synchronize robot motion start with arc strike and gas pre-flow timing */
            }

            action abortOperation() {
                /* Issue emergency halt to all subsystems */
            }
        }

        part def VisionSystem {
            attribute cameraResolution : String = "4096x3072";
            attribute frameRate : Real = 60;
            attribute fieldOfView : AngleValue = 45;
            attribute scanComplete : Boolean = false;
            attribute monitoringActive : Boolean = false;
            attribute lastScanData : ScanData;
            attribute detectedDefects : WeldDefect[*];
            attribute lastBeadData : WeldBead;
            attribute calibrationValid : Boolean = true;

            port imageOutput : ImagePort;
            port dataOutput : DataPort;
            port controlPort : ControlPort;

            action scanWorkpiece(in workpiece : Workpiece, out scanData : ScanData) {
                /* Capture images and 3D profiles to locate seam geometry */
            }

            action monitorWeld(in pathPlan : WeldPathPlan, out beadData : WeldBead) {
                /* Continuously image the molten pool and solidified bead during welding */
            }

            action detectDefects(in beadData : WeldBead, out defects : WeldDefect[*]) {
                /* Classify and locate defects from bead imagery */
            }

            action generateQualityReport(in bead : WeldBead, in defects : WeldDefect[*], out report : QualityReport) {
                /* Compute overall quality score and pass/fail decision */
            }

            action calibrate() {
                /* Perform internal camera and laser profiler calibration */
            }
        }

        part def WorkpieceFixture {
            attribute clampingForce : ForceValue = 500;
            attribute maxWorkpieceSize : LengthValue[3];
            attribute workpieceLoaded : Boolean = false;
            attribute fixtureType : String = "PneumaticClamp";
            attribute workpiece : Workpiece;

            action clampWorkpiece(in wp : Workpiece) {
                /* Actuate clamps to hold workpiece securely */
            }

            action releaseWorkpiece() {
                /* Release clamps and allow part removal */
            }

            action positionWorkpiece(in xOffset : LengthValue, in yOffset : LengthValue, in zOffset : LengthValue) {
                /* Adjust fixture orientation for optimal welding access */
            }
        }

        part def SafetyEnclosure {
            attribute doorInterlocked : Boolean = true;
            attribute emergencyStopActive : Boolean = false;
            attribute lightCurtainTripped : Boolean = false;
            attribute ventilationActive : Boolean = true;
            attribute enclosureDoorClosed : Boolean = true;
            attribute fumeExtractionRate : Real;

            port safetyOutput : SafetyPort;
            port controlPort : ControlPort;

            action triggerEmergencyStop() {
                /* Open safety circuit to halt all motion and power */
            }

            action resetEmergencyStop() {
                /* Require manual reset after verifying all clear conditions */
            }

            action monitorSafetySensors() {
                /* Continuously poll door switch, light curtain, and E-stop buttons */
            }

            action startVentilation() {
                /* Activate fume extraction system */
            }
        }

        part def HumanInterfacePanel {
            attribute displayType : String = "12 inch touchscreen";
            attribute operatorLoggedIn : Boolean = false;
            attribute currentMode : String = "Automatic";

            port controlPort : ControlPort;

            action displayStatus(in status : String) {
                /* Show current cell state and telemetry */
            }

            action acknowledgeAlarm() {
                /* Operator clears active alarms */
            }

            action selectProgram(in programId : String) {
                /* Load welding program from library */
            }
        }
    }

    part def WeldingCell {
        attribute cellId : String = "WAC-001";
        attribute manufacturer : String = "Wolf Robotics";
        attribute cellStatus : String = "Offline";
        attribute workpiecePresent : Boolean = false;
        attribute scanComplete : Boolean = false;
        attribute pathPlanned : Boolean = false;
        attribute weldPassComplete : Boolean = false;
        attribute qualityPass : Boolean = false;
        attribute reworkAttempts : Integer = 0;
        attribute maxReworkAttempts : Integer = 2;
        attribute emergencyStopTriggered : Boolean = false;
        attribute resetCommand : Boolean = false;
        attribute partsCompleted : Integer = 0;
        attribute totalRunTime : Real = 0;
        attribute currentScanData : ScanData;
        attribute currentPathPlan : WeldPathPlan;
        attribute currentQualityReport : QualityReport;
        attribute currentBead : WeldBead;
        attribute currentDefects : WeldDefect[*];

        part roboticArm : RoboticArm;
        part weldingTorch : WeldingTorch;
        part powerSupply : PowerSupply;
        part wireFeedUnit : WireFeedUnit;
        part wireSpool : WireSpool;
        part shieldingGasSupply : ShieldingGasSupply;
        part systemController : SystemController;
        part visionSystem : VisionSystem;
        part workpieceFixture : WorkpieceFixture;
        part safetyEnclosure : SafetyEnclosure;
        part humanInterface : HumanInterfacePanel;

        flow of ElectricPower from powerSupply.powerOutput to weldingTorch.powerInput;
        flow of WeldingWire from wireSpool.wireOutput to wireFeedUnit.wireInput;
        flow of WeldingWire from wireFeedUnit.wireOutput to weldingTorch.wireInput;
        flow of ShieldingGas from shieldingGasSupply.gasOutput to weldingTorch.gasInput;

        connection from systemController.robotControl to roboticArm.controlPort;
        connection from systemController.torchControl to weldingTorch.controlPort;
        connection from systemController.powerControl to powerSupply.controlPort;
        connection from systemController.wireFeedControl to wireFeedUnit.controlPort;
        connection from systemController.gasControl to shieldingGasSupply.controlPort;
        connection from visionSystem.dataOutput to systemController.visionData;
        connection from visionSystem.controlPort to systemController.visionData;
        connection from safetyEnclosure.safetyOutput to systemController.robotControl;
        connection from humanInterface.controlPort to systemController.robotControl;

        state machine CellStateMachine {
            state idle {
                entry action {
                    cellStatus = "Idle";
                    powerSupply.powerOff();
                    shieldingGasSupply.stopFlow();
                    wireFeedUnit.stopFeed();
                    scanComplete = false;
                    pathPlanned = false;
                    weldPassComplete = false;
                    qualityPass = false;
                    reworkAttempts = 0;
                }
                do action {
                    safetyEnclosure.monitorSafetySensors();
                }
            }

            state scanning {
                entry action {
                    cellStatus = "Scanning";
                    visionSystem.scanComplete = false;
                    scanComplete = false;
                }
                do action {
                    visionSystem.scanWorkpiece(workpieceFixture.workpiece, currentScanData);
                    scanComplete = true;
                }
                exit action {
                    visionSystem.scanComplete = true;
                }
            }

            state pathPlanning {
                entry action {
                    cellStatus = "Path Planning";
                    systemController.pathPlanned = false;
                    pathPlanned = false;
                }
                do action {
                    systemController.planWeldPath(currentScanData, currentPathPlan);
                    pathPlanned = true;
                }
                exit action {
                    systemController.pathPlanned = true;
                }
            }

            state activeWelding {
                entry action {
                    cellStatus = "Active Welding";
                    powerSupply.setOutput(currentPathPlan.targetCurrent, currentPathPlan.targetVoltage);
                    shieldingGasSupply.startFlow(currentPathPlan.targetGasFlowRate);
                    weldingTorch.purgeGas(2.0);
                    wireFeedUnit.feedWire(currentPathPlan.targetWireFeedSpeed);
                    weldingTorch.strikeArc();
                    weldPassComplete = false;
                    visionSystem.monitoringActive = true;
                }
                do action {
                    roboticArm.followPath(currentPathPlan);
                    visionSystem.monitorWeld(currentPathPlan, currentBead);
                    visionSystem.detectDefects(currentBead, currentDefects);
                    if (currentDefects->size() > 0) {
                        systemController.adjustParameters(currentDefects->first(), currentPathPlan, currentPathPlan);
                        powerSupply.setOutput(currentPathPlan.targetCurrent, currentPathPlan.targetVoltage);
                        wireFeedUnit.feedWire(currentPathPlan.targetWireFeedSpeed);
                        roboticArm.setTravelSpeed(currentPathPlan.targetTravelSpeed);
                    }
                    weldPassComplete = true;
                }
                exit action {
                    weldingTorch.extinguishArc();
                    wireFeedUnit.stopFeed();
                    shieldingGasSupply.stopFlow();
                    visionSystem.monitoringActive = false;
                }
            }

            state qualityChecking {
                entry action {
                    cellStatus = "Quality Checking";
                }
                do action {
                    visionSystem.generateQualityReport(currentBead, currentDefects, currentQualityReport);
                    if (currentQualityReport.pass) {
                        qualityPass = true;
                    } else {
                        qualityPass = false;
                        reworkAttempts = reworkAttempts + 1;
                    }
                }
            }

            state faulted {
                entry action {
                    cellStatus = "Faulted";
                    weldingTorch.extinguishArc();
                    powerSupply.powerOff();
                    wireFeedUnit.stopFeed();
                    shieldingGasSupply.stopFlow();
                    roboticArm.homeAllJoints();
                }
                do action {
                    safetyEnclosure.monitorSafetySensors();
                }
            }

            transition from idle to scanning when workpiecePresent == true and safetyEnclosure.enclosureDoorClosed == true;
            transition from scanning to pathPlanning when scanComplete == true;
            transition from pathPlanning to activeWelding when pathPlanned == true;
            transition from activeWelding to qualityChecking when weldPassComplete == true;
            transition from qualityChecking to idle when qualityPass == true;
            transition from qualityChecking to activeWelding when qualityPass == false and reworkAttempts < maxReworkAttempts;
            transition from idle to faulted when safetyEnclosure.emergencyStopActive == true;
            transition from scanning to faulted when safetyEnclosure.emergencyStopActive == true;
            transition from pathPlanning to faulted when safetyEnclosure.emergencyStopActive == true;
            transition from activeWelding to faulted when safetyEnclosure.emergencyStopActive == true;
            transition from qualityChecking to faulted when safetyEnclosure.emergencyStopActive == true;
            transition from faulted to idle when safetyEnclosure.emergencyStopActive == false and resetCommand == true;
        }
    }

    package Requirements {
        requirement def WeldingQualityRequirement {
            doc /* The welding cell shall produce welds meeting minimum quality standards for high-precision applications */;
            attribute minQualityScore : QualityScoreValue = 95;
            attribute maxBeadWidthDeviation : LengthValue = 0.5;
            attribute minPenetration : PenetrationValue = 3;
            attribute maxDefectCount : Integer = 0;
            attribute targetBeadWidth : BeadWidthValue = 6;
            attribute targetBeadHeight : BeadHeightValue = 2;
            subject weldingCell : WeldingCell {
                weldingCell.currentQualityReport.overallQuality >= minQualityScore
                and weldingCell.currentQualityReport.defects->size() <= maxDefectCount
            }
        }

        requirement def SeamDetectionRequirement {
            doc /* The vision system shall detect seam location and geometry with sub-millimeter accuracy */;
            attribute positionAccuracy : LengthValue = 0.1;
            attribute geometryAccuracy : LengthValue = 0.2;
            attribute maxScanTime : Real = 5;
            subject visionSystem : VisionSystem {
                /* Vision scan accuracy shall be within specified tolerance */
            }
        }

        requirement def AdaptiveControlRequirement {
            doc /* The controller shall adaptively adjust welding parameters in real time to correct detected defects */;
            attribute maxResponseTime : Real = 0.1;
            attribute parameterAdjustmentRange : Real = 0.2;
            attribute correctionSuccessRate : QualityScoreValue = 90;
            subject systemController : SystemController {
                systemController.responseTime <= maxResponseTime
                and systemController.adaptiveControlEnabled == true
            }
        }

        requirement def SafetyRequirement {
            doc /* The cell shall maintain safety under all operating conditions with fail-safe emergency stop */;
            attribute emergencyStopResponseTime : Real = 0.05;
            attribute doorInterlockRequired : Boolean = true;
            attribute lightCurtainResponseTime : Real = 0.02;
            attribute fumeExtractionRequired : Boolean = true;
            subject safetyEnclosure : SafetyEnclosure {
                safetyEnclosure.doorInterlocked == doorInterlockRequired
                and safetyEnclosure.ventilationActive == fumeExtractionRequired
            }
        }

        requirement def ThroughputRequirement {
            doc /* The cell shall support high production throughput with minimal downtime */;
            attribute minPartsPerHour : Integer = 30;
            attribute maxCycleTime : Real = 120;
            attribute minAvailability : QualityScoreValue = 95;
            subject weldingCell : WeldingCell {
                /* Production throughput shall meet minimum parts per hour */
            }
        }

        requirement def RoboticArmRequirement {
            doc /* The robotic arm shall provide six degrees of freedom with sufficient reach and precision for complex weld geometries */;
            attribute numJoints : Integer = 6;
            attribute minReach : LengthValue = 1500;
            attribute minPayload : MassValue = 10;
            attribute maxRepeatability : LengthValue = 0.05;
            subject roboticArm : RoboticArm {
                roboticArm.numJoints == numJoints
                and roboticArm.maxReach >= minReach
                and roboticArm.payloadCapacity >= minPayload
                and roboticArm.repeatability <= maxRepeatability
            }
        }

        requirement def WireFeedRequirement {
            doc /* The wire feed unit shall supply welding wire at controlled and stable speed */;
            attribute minFeedSpeed : WireFeedSpeedValue = 500;
            attribute maxFeedSpeed : WireFeedSpeedValue = 20000;
            attribute speedStability : Real = 0.02;
            subject wireFeedUnit : WireFeedUnit {
                wireFeedUnit.maxFeedSpeed >= maxFeedSpeed
            }
        }

        requirement def PowerSupplyRequirement {
            doc /* The power supply shall deliver stable welding current and voltage across the operating range */;
            attribute maxCurrent : CurrentValue = 600;
            attribute maxVoltage : VoltageValue = 50;
            attribute currentStability : Real = 0.01;
            subject powerSupply : PowerSupply {
                powerSupply.maxCurrent >= maxCurrent
                and powerSupply.maxVoltage >= maxVoltage
            }
        }

        requirement weldingCellQuality : WeldingQualityRequirement {
            doc /* Wolf Automated Welding Cell shall meet welding quality standard */;
        }

        requirement seamDetection : SeamDetectionRequirement {
            doc /* Vision system seam detection accuracy requirement */;
        }

        requirement adaptiveControl : AdaptiveControlRequirement {
            doc /* Real-time adaptive parameter control requirement */;
        }

        requirement cellSafety : SafetyRequirement {
            doc /* Welding cell safety requirement */;
        }

        requirement throughput : ThroughputRequirement {
            doc /* Production throughput requirement */;
        }

        requirement armSpec : RoboticArmRequirement {
            doc /* Six-joint robotic arm specification requirement */;
        }

        requirement wireFeedSpec : WireFeedRequirement {
            doc /* Wire feed unit specification requirement */;
        }

        requirement powerSpec : PowerSupplyRequirement {
            doc /* Power supply specification requirement */;
        }
    }
}
