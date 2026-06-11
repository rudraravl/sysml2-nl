package SurgicalLightingSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Illuminance :> Real {
        unit = "lx";
    }

    attribute def ColorTemperature :> Real {
        unit = "K";
    }

    attribute def Power :> Real {
        unit = "W";
    }

    attribute def Voltage :> Real {
        unit = "V";
    }

    attribute def Current :> Real {
        unit = "A";
    }

    attribute def Angle :> Real {
        unit = "deg";
    }

    attribute def Temperature :> Real {
        unit = "degC";
    }

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    attribute def Percentage :> Real {
        unit = "%";
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    item def LightBeam {
        attribute centralIlluminance : Illuminance;
        attribute colorTemperature : ColorTemperature;
        attribute fieldDiameter : Length;
        attribute shadowDilution : Percentage;
        attribute heatAtField : Power;
    }

    item def UserCommand {
        attribute requestedOn : Boolean;
        attribute requestedIntensity : Percentage;
        attribute requestedColorTemperature : ColorTemperature;
        attribute enableSterileHandleControl : Boolean;
    }

    item def StatusMessage {
        attribute lampOn : Boolean;
        attribute activeIntensity : Percentage;
        attribute activeColorTemperature : ColorTemperature;
        attribute faultPresent : Boolean;
        attribute overTemperature : Boolean;
        attribute backupPowerActive : Boolean;
    }

    item def ThermalCondition {
        attribute ledBoardTemperature : Temperature;
        attribute housingTemperature : Temperature;
        attribute coolingFanSpeed : Percentage;
    }

    port def PowerInputPort {
        in item powerIn : ElectricalPower;
    }

    port def ControlInputPort {
        in item commandIn : UserCommand;
    }

    port def StatusOutputPort {
        out item statusOut : StatusMessage;
    }

    port def LightOutputPort {
        out item emittedBeam : LightBeam;
    }

    port def ThermalMonitorPort {
        out item thermalStatus : ThermalCondition;
    }

    port def InternalPowerPort {
        inout item suppliedPower : ElectricalPower;
    }

    port def InternalControlPort {
        inout item controlSignal : UserCommand;
        inout item statusSignal : StatusMessage;
    }

    requirement def ProvideSurgicalIllumination {
        doc /* The surgical lighting system shall provide a controllable, shadow-reduced, cool white light field that supports visualization of a surgical site during clinical procedures. */
    }

    requirement def MaintainIlluminance {
        doc /* When enabled, the system shall provide central illuminance between 40000 lx and 160000 lx at the surgical field. */
        attribute minIlluminance : Illuminance = 40000;
        attribute maxIlluminance : Illuminance = 160000;
    }

    requirement def ControlIntensity {
        doc /* The system shall allow the clinical user to adjust light intensity from 20 percent to 100 percent without interrupting illumination. */
        attribute minimumIntensity : Percentage = 20;
        attribute maximumIntensity : Percentage = 100;
    }

    requirement def ControlColorTemperature {
        doc /* The system shall allow selectable correlated color temperature settings appropriate for tissue contrast. */
        attribute minimumCct : ColorTemperature = 3500;
        attribute maximumCct : ColorTemperature = 5000;
    }

    requirement def LimitHeatAtField {
        doc /* The system shall limit heat contribution at the illuminated field to reduce tissue drying and staff discomfort. */
        attribute maximumHeatAtField : Power = 20;
    }

    requirement def DetectFaults {
        doc /* The system shall detect power, thermal, LED-array, and control faults and report degraded status to the user interface. */
    }

    requirement def ProvideBackupOperation {
        doc /* The system shall transfer to backup power when normal mains power is unavailable and sufficient reserve energy remains. */
        attribute minimumBackupDuration : TimeDuration = 1800;
    }

    part def SurgicalLightingSystem {
        doc /* A ceiling-mounted surgical lighting system whose primary high-level function is to illuminate the operative field with adjustable, high-intensity, low-heat light while enabling sterile user control and status awareness. */

        port mainsPower : PowerInputPort;
        port wallControl : ControlInputPort;
        port sterileHandleControl : ControlInputPort;
        port systemStatus : StatusOutputPort;
        port surgicalFieldLight : LightOutputPort;

        attribute nominalInputVoltage : Voltage = 120;
        attribute maximumInputPower : Power = 180;
        attribute standbyPower : Power = 8;
        attribute selectedIntensity : Percentage;
        attribute selectedColorTemperature : ColorTemperature;
        attribute systemEnabled : Boolean;
        attribute faultPresent : Boolean;

        part powerSubsystem : PowerSubsystem;
        part controller : LightingController;
        part lightHead : LightHead;
        part supportArm : ArticulatedSupportArm;
        part userInterface : UserInterface;
        part thermalManagement : ThermalManagementSubsystem;
        part backupSupply : BackupPowerSubsystem;

        connect mainsPower.powerIn to powerSubsystem.acInput.powerIn;
        connect backupSupply.backupPowerOut.suppliedPower to powerSubsystem.backupInput.suppliedPower;
        connect powerSubsystem.dcOutput.suppliedPower to controller.powerPort.suppliedPower;
        connect powerSubsystem.dcOutput.suppliedPower to lightHead.powerPort.suppliedPower;
        connect powerSubsystem.dcOutput.suppliedPower to thermalManagement.powerPort.suppliedPower;

        connect wallControl.commandIn to userInterface.wallCommand.commandIn;
        connect sterileHandleControl.commandIn to userInterface.handleCommand.commandIn;
        connect userInterface.controlBus.controlSignal to controller.userControl.controlSignal;
        connect controller.lightControl.controlSignal to lightHead.controlPort.controlSignal;
        connect thermalManagement.thermalReport.thermalStatus to controller.thermalInput.thermalStatus;
        connect controller.statusBus.statusSignal to userInterface.statusBus.statusSignal;
        connect userInterface.statusOut.statusOut to systemStatus.statusOut;
        connect lightHead.lightOutput.emittedBeam to surgicalFieldLight.emittedBeam;

        satisfy ProvideSurgicalIllumination by SurgicalLightingSystem;
        satisfy MaintainIlluminance by lightHead;
        satisfy ControlIntensity by userInterface;
        satisfy ControlColorTemperature by userInterface;
        satisfy LimitHeatAtField by thermalManagement;
        satisfy DetectFaults by controller;
        satisfy ProvideBackupOperation by backupSupply;
    }

    part def PowerSubsystem {
        port acInput : PowerInputPort;
        port backupInput : InternalPowerPort;
        port dcOutput : InternalPowerPort;

        attribute acVoltage : Voltage = 120;
        attribute dcBusVoltage : Voltage = 48;
        attribute maximumDcPower : Power = 160;
        attribute mainsAvailable : Boolean;
        attribute usingBackupPower : Boolean;

        part acDcConverter : AcDcConverter;
        part powerConditioner : PowerConditioner;
        part protectionModule : ElectricalProtectionModule;

        connect acInput.powerIn to acDcConverter.acInput.powerIn;
        connect acDcConverter.dcOutput.suppliedPower to protectionModule.inputPower.suppliedPower;
        connect backupInput.suppliedPower to protectionModule.backupPower.suppliedPower;
        connect protectionModule.protectedOutput.suppliedPower to powerConditioner.inputPower.suppliedPower;
        connect powerConditioner.conditionedOutput.suppliedPower to dcOutput.suppliedPower;
    }

    part def AcDcConverter {
        port acInput : PowerInputPort;
        port dcOutput : InternalPowerPort;

        attribute conversionEfficiency : Percentage = 92;
        attribute outputVoltage : Voltage = 48;
        attribute ratedPower : Power = 180;
    }

    part def PowerConditioner {
        port inputPower : InternalPowerPort;
        port conditionedOutput : InternalPowerPort;

        attribute rippleLimit : Percentage = 2;
        attribute regulatedVoltage : Voltage = 48;
    }

    part def ElectricalProtectionModule {
        port inputPower : InternalPowerPort;
        port backupPower : InternalPowerPort;
        port protectedOutput : InternalPowerPort;

        attribute overCurrentTrip : Current = 5;
        attribute surgeProtected : Boolean = true;
        attribute isolationVerified : Boolean;
    }

    part def BackupPowerSubsystem {
        port backupPowerOut : InternalPowerPort;

        attribute batteryVoltage : Voltage = 48;
        attribute reserveEnergy : Energy = 360000;
        attribute backupDurationAvailable : TimeDuration = 1800;
        attribute charging : Boolean;
        attribute supplyingLoad : Boolean;
    }

    part def LightingController {
        port powerPort : InternalPowerPort;
        port userControl : InternalControlPort;
        port lightControl : InternalControlPort;
        port thermalInput : ThermalMonitorPort;
        port statusBus : InternalControlPort;

        attribute requestedIntensity : Percentage = 80;
        attribute requestedColorTemperature : ColorTemperature = 4300;
        attribute lampEnabled : Boolean = false;
        attribute overTemperatureFault : Boolean = false;
        attribute ledFault : Boolean = false;
        attribute powerFault : Boolean = false;
        attribute controlFault : Boolean = false;

        action perform ProcessUserCommand {
            in item command : UserCommand;
            out item adjustedCommand : UserCommand;
        }

        action perform EvaluateSystemHealth {
            in item thermal : ThermalCondition;
            out item status : StatusMessage;
        }

        state behavior ControllerStateMachine {
            entry action EvaluateSystemHealth;

            state Off;
            state Standby;
            state Illuminating;
            state Degraded;
            state FaultShutdown;

            transition initial then Off;

            transition Off_to_Standby
                first Off
                accept UserCommand
                if commandIn.requestedOn == true
                then Standby;

            transition Standby_to_Illuminating
                first Standby
                if powerFault == false and overTemperatureFault == false
                then Illuminating;

            transition Illuminating_to_Degraded
                first Illuminating
                if ledFault == true or powerFault == true
                then Degraded;

            transition Illuminating_to_FaultShutdown
                first Illuminating
                if overTemperatureFault == true
                then FaultShutdown;

            transition Degraded_to_Illuminating
                first Degraded
                if ledFault == false and powerFault == false and overTemperatureFault == false
                then Illuminating;

            transition FaultShutdown_to_Standby
                first FaultShutdown
                accept UserCommand
                if commandIn.requestedOn == false
                then Standby;

            transition Standby_to_Off
                first Standby
                accept UserCommand
                if commandIn.requestedOn == false
                then Off;
        }
    }

    part def UserInterface {
        port wallCommand : ControlInputPort;
        port handleCommand : ControlInputPort;
        port controlBus : InternalControlPort;
        port statusBus : InternalControlPort;
        port statusOut : StatusOutputPort;

        attribute displayedIntensity : Percentage;
        attribute displayedColorTemperature : ColorTemperature;
        attribute audibleAlarmActive : Boolean;
        attribute sterileHandleEnabled : Boolean = true;

        part wallPanel : WallControlPanel;
        part sterileHandle : SterileHandle;
        part statusDisplay : StatusDisplay;

        connect wallCommand.commandIn to wallPanel.commandInput.commandIn;
        connect handleCommand.commandIn to sterileHandle.commandInput.commandIn;
        connect wallPanel.controlOutput.controlSignal to controlBus.controlSignal;
        connect sterileHandle.controlOutput.controlSignal to controlBus.controlSignal;
        connect statusBus.statusSignal to statusDisplay.statusInput.statusSignal;
        connect statusDisplay.statusOutput.statusOut to statusOut.statusOut;
    }

    part def WallControlPanel {
        port commandInput : ControlInputPort;
        port controlOutput : InternalControlPort;

        attribute intensitySetpoint : Percentage = 80;
        attribute cctSetpoint : ColorTemperature = 4300;
        attribute powerButtonPressed : Boolean;
    }

    part def SterileHandle {
        port commandInput : ControlInputPort;
        port controlOutput : InternalControlPort;

        attribute rotationAngle : Angle;
        attribute touchDetected : Boolean;
        attribute intensityStepSize : Percentage = 10;
    }

    part def StatusDisplay {
        port statusInput : InternalControlPort;
        port statusOutput : StatusOutputPort;

        attribute showsFaultIcon : Boolean;
        attribute showsBackupPowerIcon : Boolean;
        attribute brightness : Percentage = 70;
    }

    part def LightHead {
        port powerPort : InternalPowerPort;
        port controlPort : InternalControlPort;
        port lightOutput : LightOutputPort;

        attribute maximumCentralIlluminance : Illuminance = 160000;
        attribute minimumCentralIlluminance : Illuminance = 40000;
        attribute currentCentralIlluminance : Illuminance;
        attribute currentColorTemperature : ColorTemperature;
        attribute fieldDiameter : Length = 0.22;
        attribute heatAtField : Power;
        attribute focusAngle : Angle;

        part ledArray : MultiChannelLedArray;
        part opticalSystem : OpticalSystem;
        part focusMechanism : FocusMechanism;
        part handleMount : SterileHandleMount;

        connect powerPort.suppliedPower to ledArray.powerPort.suppliedPower;
        connect controlPort.controlSignal to ledArray.controlPort.controlSignal;
        connect ledArray.rawLight.emittedBeam to opticalSystem.inputLight.emittedBeam;
        connect focusMechanism.focusedLight.emittedBeam to lightOutput.emittedBeam;
        connect opticalSystem.shapedLight.emittedBeam to focusMechanism.inputLight.emittedBeam;
    }

    part def MultiChannelLedArray {
        port powerPort : InternalPowerPort;
        port controlPort : InternalControlPort;
        port rawLight : LightOutputPort;

        attribute warmChannelPower : Power;
        attribute neutralChannelPower : Power;
        attribute coolChannelPower : Power;
        attribute ledJunctionTemperature : Temperature;
        attribute expectedServiceLife : TimeDuration = 216000000;
        attribute failedLedCount : Integer = 0;
    }

    part def OpticalSystem {
        port inputLight : LightOutputPort;
        port shapedLight : LightOutputPort;

        attribute reflectorEfficiency : Percentage = 88;
        attribute lensTransmission : Percentage = 94;
        attribute shadowDilution : Percentage = 75;
        attribute glareLimited : Boolean = true;
    }

    part def FocusMechanism {
        port inputLight : LightOutputPort;
        port focusedLight : LightOutputPort;

        attribute focusDiameterMinimum : Length = 0.16;
        attribute focusDiameterMaximum : Length = 0.28;
        attribute currentFocusDiameter : Length = 0.22;
        attribute yokeTiltAngle : Angle;
    }

    part def SterileHandleMount {
        attribute removableHandleAttached : Boolean;
        attribute sterilizableInterface : Boolean = true;
    }

    part def ArticulatedSupportArm {
        attribute verticalTravel : Length = 1.1;
        attribute horizontalReach : Length = 1.8;
        attribute rotationRange : Angle = 330;
        attribute driftCompensated : Boolean = true;

        part ceilingMount : CeilingMount;
        part springArm : SpringBalancedArm;
        part yoke : LightHeadYoke;
    }

    part def CeilingMount {
        attribute mountingLoadCapacity : Mass = 45;
        attribute mechanicalGroundBonded : Boolean = true;
    }

    part def SpringBalancedArm {
        attribute counterbalanceForce : Force;
        attribute brakeFriction : Force;
        attribute repositioningForceLimit : Force = 25;
    }

    part def LightHeadYoke {
        attribute panAngle : Angle;
        attribute tiltAngle : Angle;
        attribute rotationStopEnabled : Boolean = true;
    }

    part def ThermalManagementSubsystem {
        port powerPort : InternalPowerPort;
        port thermalReport : ThermalMonitorPort;

        attribute maximumLedBoardTemperature : Temperature = 85;
        attribute maximumHousingTemperature : Temperature = 50;
        attribute fanCommand : Percentage;
        attribute passiveHeatSinkArea : Area = 0.18;
        attribute overTemperature : Boolean;

        part heatSink : HeatSink;
        part fan : CoolingFan;
        part temperatureSensor : TemperatureSensor;

        action perform RegulateCooling {
            in item sensedThermalCondition : ThermalCondition;
            out item commandedFanSpeed : ThermalCondition;
        }

        state behavior ThermalStateMachine {
            state NormalCooling;
            state HighCooling;
            state OverTemperature;

            transition initial then NormalCooling;

            transition Normal_to_High
                first NormalCooling
                if ledBoardTemperature > 70
                then HighCooling;

            transition High_to_Normal
                first HighCooling
                if ledBoardTemperature < 60
                then NormalCooling;

            transition High_to_OverTemperature
                first HighCooling
                if ledBoardTemperature > 85
                then OverTemperature;

            transition OverTemperature_to_High
                first OverTemperature
                if ledBoardTemperature < 75
                then HighCooling;
        }
    }

    part def HeatSink {
        attribute thermalResistance : Real = 0.65;
        attribute surfaceArea : Area = 0.18;
    }

    part def CoolingFan {
        attribute speedCommand : Percentage;
        attribute airflowRate : Real = 18;
        attribute acousticNoise : Real = 32;
    }

    part def TemperatureSensor {
        attribute measuredLedBoardTemperature : Temperature;
        attribute measuredHousingTemperature : Temperature;
        attribute accuracy : Temperature = 1.5;
    }

    action def IlluminateSurgicalField {
        in item electricalPower : ElectricalPower;
        in item userCommand : UserCommand;
        out item surgicalLight : LightBeam;
        out item status : StatusMessage;

        first start;
        then validatePower;
        then computeIntensity;
        then mixLedChannels;
        then shapeBeam;
        then monitorTemperature;
        then emitLight;
        then publishStatus;
        then done;

        action validatePower;
        action computeIntensity;
        action mixLedChannels;
        action shapeBeam;
        action monitorTemperature;
        action emitLight;
        action publishStatus;
    }

    action def RespondToFault {
        in item status : StatusMessage;
        out item safeStatus : StatusMessage;

        first detectFault;
        then reduceOutput;
        then notifyUser;
        then maintainSafeState;
        then done;

        action detectFault;
        action reduceOutput;
        action notifyUser;
        action maintainSafeState;
    }

    allocation def IlluminationFunctionAllocation {
        end function : IlluminateSurgicalField;
        end system : SurgicalLightingSystem;
    }

    dependency SurgicalLightingSystemPrimaryFunction {
        client IlluminateSurgicalField;
        supplier SurgicalLightingSystem;
    }

    assert requirement ProvideSurgicalIllumination {
        subject surgicalLightingSystem : SurgicalLightingSystem;
    }

    assert requirement MaintainIlluminance {
        subject lightHead : LightHead;
    }

    assert requirement ControlIntensity {
        subject userInterface : UserInterface;
    }

    assert requirement ControlColorTemperature {
        subject userInterface : UserInterface;
    }

    assert requirement LimitHeatAtField {
        subject thermalManagement : ThermalManagementSubsystem;
    }

    assert requirement DetectFaults {
        subject controller : LightingController;
    }

    assert requirement ProvideBackupOperation {
        subject backupSupply : BackupPowerSubsystem;
    }
}