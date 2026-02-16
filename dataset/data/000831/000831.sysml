package 'Welner Table Ophthalmic Examination System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def DiopterValue :> Real;

    item def PowerSignal {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute frequency : FrequencyValue;
    }

    item def HeightCommand {
        attribute targetHeight : LengthValue;
        attribute speed : Real;
    }

    item def TiltCommand {
        attribute targetAngle : AngleValue;
        attribute speed : Real;
    }

    item def PositionFeedback {
        attribute currentHeight : LengthValue;
        attribute currentTilt : AngleValue;
        attribute timestamp : Real;
    }

    item def LensConfiguration {
        attribute sphericalPower : DiopterValue;
        attribute cylindricalPower : DiopterValue;
        attribute axis : AngleValue;
    }

    port def PowerPort {
        in powerSignal : PowerSignal;
    }

    port def ControlPort {
        in heightCmd : HeightCommand;
        in tiltCmd : TiltCommand;
        out positionFb : PositionFeedback;
    }

    port def InstrumentMountPort {
        out mountingForce : ForceValue;
        in instrumentLoad : MassValue;
    }

    part def PowerSupply {
        port acInput {
            in line : PowerSignal;
        }
        port dcOutput {
            out power : PowerSignal;
        }
        attribute inputVoltage : ElectricPotentialValue = 120.0 [V];
        attribute outputVoltage : ElectricPotentialValue = 24.0 [V];
        attribute maxCurrent : ElectricCurrentValue = 10.0 [A];
    }

    part def LinearActuator {
        port powerIn : PowerPort;
        attribute minHeight : LengthValue = 0.60 [m];
        attribute maxHeight : LengthValue = 1.20 [m];
        attribute currentPosition : LengthValue;
        attribute maxLoad : ForceValue = 2000.0 [N];
        attribute speed : Real = 0.05;
    }

    part def TiltActuator {
        port powerIn : PowerPort;
        attribute minAngle : AngleValue = -15.0 ['°'];
        attribute maxAngle : AngleValue = 45.0 ['°'];
        attribute currentAngle : AngleValue;
        attribute maxTorque : TorqueValue = 150.0 [N*m];
        attribute speed : Real = 2.0;
    }

    part def InstrumentArm {
        port mountPoint : InstrumentMountPort;
        attribute armLength : LengthValue = 0.80 [m];
        attribute armWeight : MassValue = 15.0 [kg];
        attribute maxInstrumentLoad : MassValue = 25.0 [kg];
    }

    part def PatientChair {
        port powerIn : PowerPort;
        port controlIn : ControlPort;
        part heightActuator : LinearActuator {
            :>> minHeight = 0.45 [m];
            :>> maxHeight = 0.75 [m];
        }
        attribute seatWidth : LengthValue = 0.55 [m];
        attribute seatDepth : LengthValue = 0.50 [m];
        attribute maxPatientMass : MassValue = 180.0 [kg];
    }

    part def Phoropter {
        port powerIn : PowerPort;
        port lensControl {
            in lensConfig : LensConfiguration;
        }
        port mounting {
            out weight : MassValue;
        }
        attribute currentSphere : DiopterValue = 0.0;
        attribute currentCylinder : DiopterValue = 0.0;
        attribute currentAxis : AngleValue = 0.0 ['°'];
        attribute sphereRange : DiopterValue = 20.0;
        attribute cylinderRange : DiopterValue = 6.0;
        attribute instrumentMass : MassValue = 8.5 [kg];
    }

    part def ControlPanel {
        port tableControl : ControlPort;
        port chairControl : ControlPort;
        port phoropterControl {
            out lensConfig : LensConfiguration;
        }
        attribute displayType : String = "touchscreen";
        attribute displaySize : LengthValue = 0.25 [m];
    }

    part def WelnerTable {
        doc /* The Welner table is a motorized, adjustable examination platform 
               that positions ophthalmic instruments at optimal heights and angles 
               for patient eye examinations. */
        
        port powerInput : PowerPort;
        port controlInterface : ControlPort;
        port instrumentMount : InstrumentMountPort;
        
        part supply : PowerSupply;
        part liftActuator : LinearActuator {
            :>> minHeight = 0.60 [m];
            :>> maxHeight = 1.20 [m];
        }
        part tiltActuator : TiltActuator {
            :>> minAngle = -15.0 ['°'];
            :>> maxAngle = 45.0 ['°'];
        }
        part arm : InstrumentArm;
        
        attribute tableLength : LengthValue = 1.20 [m];
        attribute tableWidth : LengthValue = 0.80 [m];
        attribute currentHeight : LengthValue;
        attribute currentTilt : AngleValue;
        
        connect powerInput to supply.acInput.line;
        connect supply.dcOutput.power to liftActuator.powerIn.powerSignal;
        connect supply.dcOutput.power to tiltActuator.powerIn.powerSignal;
        connect arm.mountPoint to instrumentMount;
    }

    action def AdjustTableHeight {
        in cmd : HeightCommand;
        in currentHeight : LengthValue;
        in minHeight : LengthValue;
        in maxHeight : LengthValue;
        out newHeight : LengthValue;
        out valid : Boolean;
        
        action checkBounds {
            assign valid := (cmd.targetHeight >= minHeight) and (cmd.targetHeight <= maxHeight);
        }
        then decide;
            if valid then assignValid;
            if !valid then assignCurrent;
        action assignValid {
            assign newHeight := cmd.targetHeight;
        }
        action assignCurrent {
            assign newHeight := currentHeight;
        }
    }

    action def AdjustTableTilt {
        in cmd : TiltCommand;
        in currentTilt : AngleValue;
        in minAngle : AngleValue;
        in maxAngle : AngleValue;
        out newTilt : AngleValue;
        out valid : Boolean;
        
        action checkBounds {
            assign valid := (cmd.targetAngle >= minAngle) and (cmd.targetAngle <= maxAngle);
        }
        then decide;
            if valid then assignValid;
            if !valid then assignCurrent;
        action assignValid {
            assign newTilt := cmd.targetAngle;
        }
        action assignCurrent {
            assign newTilt := currentTilt;
        }
    }

    action def ConfigurePhoropter {
        in config : LensConfiguration;
        in sphereRange : DiopterValue;
        in cylinderRange : DiopterValue;
        out sphere : DiopterValue;
        out cylinder : DiopterValue;
        out axis : AngleValue;
        out valid : Boolean;
        
        first start;
        then action checkRanges {
            assign valid := (abs(config.sphericalPower) <= sphereRange) and 
                           (abs(config.cylindricalPower) <= cylinderRange);
        }
        then decide;
            if valid then applyConfig;
            if !valid then applyDefaults;
        action applyConfig {
            assign sphere := config.sphericalPower;
            assign cylinder := config.cylindricalPower;
            assign axis := config.axis;
        }
        action applyDefaults {
            assign sphere := 0.0;
            assign cylinder := 0.0;
            assign axis := 0.0 ['°'];
        }
        then done;
    }

    action def PerformEyeExamination {
        in patientHeight : LengthValue;
        in examType : String;
        out examComplete : Boolean;
        
        first start;
        then action positionChair {
            out chairHeight : LengthValue;
        }
        then action positionTable {
            out tableHeight : LengthValue;
            out tableTilt : AngleValue;
        }
        then action alignInstruments {
            out instrumentReady : Boolean;
        }
        then action performRefraction {
            out refractionData : LensConfiguration;
        }
        then action recordResults {
            in data : LensConfiguration;
        }
        then assign examComplete := true;
        then done;
    }

    state def WelnerTableStates {
        entry; then idle;
        
        state idle {
            entry assign systemReady := true;
        }
        
        transition idle_to_positioning
            first idle
            accept positionCommand
            then positioning;
        
        state positioning {
            entry action adjustPosition;
            
            state heightAdjustment {
                entry action adjustHeight : AdjustTableHeight;
            }
            
            state tiltAdjustment {
                entry action adjustTilt : AdjustTableTilt;
            }
        }
        
        transition positioning_to_examining
            first positioning
            if positionReached
            then examining;
        
        state examining {
            entry assign instrumentsActive := true;
            
            state refraction {
                entry action performRefraction;
            }
            
            state measurement {
                entry action takeMeasurement;
            }
        }
        
        transition examining_to_idle
            first examining
            if examComplete
            then idle;
        
        transition any_to_emergency
            accept emergencyStop
            then emergency;
        
        state emergency {
            entry action stopAllMotion;
        }
        
        transition emergency_to_idle
            first emergency
            accept reset
            then idle;
    }

    requirement def <'REQ-SYS-001'> PrimaryFunctionRequirement {
        doc /* The Welner table system shall provide a stable, adjustable platform 
               for positioning ophthalmic examination instruments at ergonomically 
               optimal heights and angles to facilitate comprehensive eye examinations. */
        
        subject system : OphthalmicExaminationSystem;
    }

    requirement def <'REQ-WEL-001'> HeightAdjustmentRequirement {
        doc /* The Welner table shall adjust height continuously between 
               0.60 m and 1.20 m to accommodate different patient and 
               clinician heights. */
        
        subject table : WelnerTable;
        
        require constraint {
            table.liftActuator.minHeight == 0.60 [m] and
            table.liftActuator.maxHeight == 1.20 [m]
        }
    }

    requirement def <'REQ-WEL-002'> TiltAdjustmentRequirement {
        doc /* The Welner table instrument arm shall tilt between 
               -15 degrees and +45 degrees to optimize instrument 
               positioning for various examination procedures. */
        
        subject table : WelnerTable;
        
        require constraint {
            table.tiltActuator.minAngle == -15.0 ['°'] and
            table.tiltActuator.maxAngle == 45.0 ['°']
        }
    }

    requirement def <'REQ-WEL-003'> LoadCapacityRequirement {
        doc /* The Welner table instrument arm shall support a minimum 
               load of 25 kg to accommodate standard ophthalmic instruments. */
        
        subject arm : InstrumentArm;
        
        require constraint {
            arm.maxInstrumentLoad >= 25.0 [kg]
        }
    }

    requirement def <'REQ-CHR-001'> ChairAdjustmentRequirement {
        doc /* The patient chair shall adjust height between 0.45 m and 
               0.75 m to align patient eyes with examination instruments. */
        
        subject chair : PatientChair;
        
        require constraint {
            chair.heightActuator.minHeight == 0.45 [m] and
            chair.heightActuator.maxHeight == 0.75 [m]
        }
    }

    requirement def <'REQ-PHO-001'> PhoropterRangeRequirement {
        doc /* The phoropter shall provide spherical power adjustment 
               of ±20 diopters and cylindrical power adjustment of 
               ±6 diopters for comprehensive refraction testing. */
        
        subject phoropter : Phoropter;
        
        require constraint {
            phoropter.sphereRange >= 20.0 and
            phoropter.cylinderRange >= 6.0
        }
    }

    requirement def <'REQ-SAF-001'> EmergencyStopRequirement {
        doc /* The system shall provide emergency stop functionality 
               that immediately halts all motorized motion and enters 
               a safe state. */
        
        subject system : OphthalmicExaminationSystem;
    }

    part def OphthalmicExaminationSystem {
        doc /* An integrated ophthalmic examination system centered on a 
               Welner table that coordinates motorized positioning of 
               examination instruments, patient seating, and refraction 
               equipment to enable efficient and accurate eye examinations. */
        
        part power : PowerSupply {
            :>> inputVoltage = 120.0 [V];
            :>> outputVoltage = 24.0 [V];
        }
        
        part welnerTable : WelnerTable {
            :>> currentHeight = 0.90 [m];
            :>> currentTilt = 0.0 ['°'];
        }
        
        part chair : PatientChair {
            :>> maxPatientMass = 180.0 [kg];
        }
        
        part phoropter : Phoropter {
            :>> sphereRange = 20.0;
            :>> cylinderRange = 6.0;
        }
        
        part controls : ControlPanel;
        
        connect power.dcOutput.power to welnerTable.powerInput.powerSignal;
        connect power.dcOutput.power to chair.powerIn.powerSignal;
        connect power.dcOutput.power to phoropter.powerIn.powerSignal;
        connect controls.tableControl to welnerTable.controlInterface;
        connect controls.chairControl to chair.controlIn;
        connect controls.phoropterControl.lensConfig to phoropter.lensControl.lensConfig;
        connect phoropter.mounting.weight to welnerTable.instrumentMount.instrumentLoad;
        
        perform action examSequence : PerformEyeExamination[*] ordered;
        
        exhibit state operationStates : WelnerTableStates;
        
        satisfy PrimaryFunctionRequirement;
        satisfy HeightAdjustmentRequirement by welnerTable.liftActuator;
        satisfy TiltAdjustmentRequirement by welnerTable.tiltActuator;
        satisfy LoadCapacityRequirement by welnerTable.arm;
        satisfy ChairAdjustmentRequirement by chair.heightActuator;
        satisfy PhoropterRangeRequirement by phoropter;
        satisfy EmergencyStopRequirement by operationStates;
    }
}
