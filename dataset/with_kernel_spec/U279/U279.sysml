package MedicalLaserScalpelSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    // ===== Value Types and Items =====
    item def LaserBeam;
    item def VisibleLight;

    attribute def PowerSetting :> PowerValue;
    attribute def FlowRateValue :> Real;

    enum def OperatingMode { cutting; coagulation; }

    attribute def PowerOnSignal;
    attribute def PowerOffSignal;
    attribute def FootPedalPressed;
    attribute def FootPedalReleased;
    attribute def ModeSelected;
    attribute def FaultSignal;
    attribute def ResetSignal;
    attribute def OverTemperature;
    attribute def InterlocksEngaged;

    // ===== Action Definitions =====
    action def PerformSelfTest { out success : Boolean; }
    action def GenerateLaser { in power : PowerSetting; in mode : OperatingMode; out beam : LaserBeam; }
    action def FocusBeam { in beam : LaserBeam; out focusedBeam : LaserBeam; }
    action def EmitAimingBeam { out light : VisibleLight; }
    action def SenseTemperature { out temp : TemperatureValue; }
    action def CirculateCoolant { out flowRate : FlowRateValue; }
    action def CheckInterlocks { out allEngaged : Boolean; }
    action def SenseContact { out contact : Boolean; }
    action def DeactivateLaser;

    // ===== Port Definitions =====
    port def LaserPort { out item beam : LaserBeam; }
    port def LightPort { out item light : VisibleLight; }
    port def ControlPort {
        in attribute power : PowerSetting;
        in attribute mode : OperatingMode;
        out attribute status : String;
    }
    port def SafetyPort { out attribute allEngaged : Boolean; }
    port def CoolantPort { out attribute flowRate : FlowRateValue; }
    port def ContactSensorPort { out attribute contact : Boolean; }
    port def AlertPort { out attribute alert : Boolean; }

    // ===== Part Definitions =====
    part def LaserDiodeArray { port beamOut : LaserPort; }
    part def OpticalCavity { port beamIn : ~LaserPort; port beamOut : LaserPort; }
    part def BeamShapingOptics { port beamIn : ~LaserPort; port beamOut : LaserPort; }

    part def LaserGenerator {
        part diodeArray : LaserDiodeArray;
        part opticalCavity : OpticalCavity;
        part beamShapingOptics : BeamShapingOptics;

        port beamOutput : LaserPort;
        port controlInput : ControlPort;
        port coolantInput : ~CoolantPort;

        attribute maxTemp : TemperatureValue;
        attribute currentTemp : TemperatureValue;

        perform action generate : GenerateLaser;

        connect diodeArray.beamOut to opticalCavity.beamIn;
        connect opticalCavity.beamOut to beamShapingOptics.beamIn;
        connect beamShapingOptics.beamOut to beamOutput;
    }

    part def TouchscreenDisplay {
        port controlOutput : ~ControlPort;
    }

    part def FootPedal {
        port pedalOutput { out attribute pressed : Boolean; }
    }

    part def ControlConsole {
        part display : TouchscreenDisplay;
        part footPedal : FootPedal;

        port displayControl : ControlPort;
        port systemControl : ~ControlPort;
        port safetyInput : ~SafetyPort;
        port contactInput : ~ContactSensorPort;
        port tempInput : ~AlertPort;

        connect display.controlOutput to displayControl;
    }

    part def ArticulatedArm { port beamIn : ~LaserPort; port beamOut : LaserPort; }
    part def FiberOpticCable { port beamIn : ~LaserPort; port beamOut : LaserPort; }

    part def OpticalDeliverySystem {
        part articulatedArm : ArticulatedArm;
        part fiberOpticCable : FiberOpticCable;

        port beamInput : ~LaserPort;
        port beamOutput : LaserPort;

        connect beamInput to articulatedArm.beamIn;
        connect articulatedArm.beamOut to fiberOpticCable.beamIn;
        connect fiberOpticCable.beamOut to beamOutput;
    }

    part def FocusingOptics { port beamIn : ~LaserPort; port beamOut : LaserPort; }
    part def AimingBeamEmitter { port lightOut : LightPort; }
    part def ContactSensor { port contactOut : ContactSensorPort; }

    part def SurgicalHandpiece {
        part focusingOptics : FocusingOptics;
        part aimingBeam : AimingBeamEmitter;
        part contactSensor : ContactSensor;

        port beamInput : ~LaserPort;
        port contactOutput : ContactSensorPort;
        port coolantInput : ~CoolantPort;

        perform action focus : FocusBeam;
        perform action emitAiming : EmitAimingBeam;
        perform action monitorContact : SenseContact;

        connect beamInput to focusingOptics.beamIn;
    }

    part def CoolantPump { port flowOut : CoolantPort; }
    part def CoolantReservoir;
    part def HeatExchanger;

    part def ThermalManagementSystem {
        part pump : CoolantPump;
        part reservoir : CoolantReservoir;
        part heatExchanger : HeatExchanger;

        port coolantToGenerator : CoolantPort;
        port coolantToHandpiece : CoolantPort;
        port tempAlertOut : AlertPort;

        perform action circulate : CirculateCoolant;
        perform action senseTemp : SenseTemperature;

        connect pump.flowOut to coolantToGenerator;
        connect pump.flowOut to coolantToHandpiece;
    }

    part def DoorSensor { port statusOut : SafetyPort; }
    part def KeySwitch { port statusOut : SafetyPort; }
    part def EmergencyStopButton { port statusOut : SafetyPort; }
    part def ExternalInterlock { port statusOut : SafetyPort; }

    part def SafetyInterlockSystem {
        part doorSensor : DoorSensor;
        part keySwitch : KeySwitch;
        part eStopButton : EmergencyStopButton;
        part externalInterlock : ExternalInterlock;

        port interlockStatusOut : SafetyPort;

        perform action checkInterlocks : CheckInterlocks;
    }

    // ===== Constraint Definitions =====
    constraint def InterlocksEngagedConstraint {
        in status : Boolean;
        require status == true;
    }

    constraint def TemperatureLimitConstraint {
        in current : TemperatureValue;
        in maximum : TemperatureValue;
        require current <= maximum;
    }

    // ===== State Definitions =====
    state def ConsoleStates {
        in generator : LaserGenerator;
        in safety : SafetyInterlockSystem;
        in thermal : ThermalManagementSystem;
        in handpiece : SurgicalHandpiece;

        entry; then off;

        state off;
        accept PowerOnSignal then initializing;

        state initializing {
            entry action selfTest : PerformSelfTest { out success; }
        }
        accept when selfTest.success then standby;
        accept when selfTest.success == false then fault;

        state standby;
        accept InterlocksEngaged
            if safety.checkInterlocks.allEngaged
            then ready;
        accept PowerOffSignal then off;

        state ready;
        accept ModeSelected then ready;
        accept FootPedalPressed
            if handpiece.monitorContact.contact
            then active;
        accept PowerOffSignal then off;

        state active {
            entry action generate : GenerateLaser;
            do action focus : FocusBeam;
        }
        accept FootPedalReleased then ready;
        accept FaultSignal then fault;
        accept OverTemperature then fault;
        accept PowerOffSignal then off;

        state fault {
            entry action shutdown : DeactivateLaser;
        }
        accept ResetSignal then off;
        accept PowerOffSignal then off;
    }

    // ===== Top-Level System =====
    part def LaserScalpelSystem {
        part generator : LaserGenerator;
        part console : ControlConsole;
        part delivery : OpticalDeliverySystem;
        part handpiece : SurgicalHandpiece;
        part thermal : ThermalManagementSystem;
        part safety : SafetyInterlockSystem;

        connect console.systemControl to generator.controlInput;
        connect generator.beamOutput to delivery.beamInput;
        connect delivery.beamOutput to handpiece.beamInput;
        connect thermal.coolantToGenerator to generator.coolantInput;
        connect thermal.coolantToHandpiece to handpiece.coolantInput;
        connect handpiece.contactOutput to console.contactInput;
        connect safety.interlockStatusOut to console.safetyInput;
        connect thermal.tempAlertOut to console.tempInput;

        exhibit state systemStates : ConsoleStates {
            in generator = generator;
            in safety = safety;
            in thermal = thermal;
            in handpiece = handpiece;
        }
    }

    // ===== Requirements =====
    requirement def SafeOperationRequirement {
        doc /* The laser shall not fire unless all safety interlocks are engaged. */
        subject system : LaserScalpelSystem;
        require constraint interlockCheck : InterlocksEngagedConstraint {
            in status = system.safety.checkInterlocks.allEngaged;
        }
    }

    requirement def ThermalSafetyRequirement {
        doc /* The system shall enter fault state if temperature exceeds safe limits. */
        subject system : LaserScalpelSystem;
        require constraint tempCheck : TemperatureLimitConstraint {
            in current = system.generator.currentTemp;
            in maximum = system.generator.maxTemp;
        }
    }

    requirement def PrecisionCuttingRequirement {
        doc /* The system shall deliver a focused laser beam for precise surgical incisions. */
        subject system : LaserScalpelSystem;
    }

    requirement safeOp : SafeOperationRequirement;
    requirement thermalSafety : ThermalSafetyRequirement;
    requirement precisionCut : PrecisionCuttingRequirement;
}
