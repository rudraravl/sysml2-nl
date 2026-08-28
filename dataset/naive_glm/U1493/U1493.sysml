package ScrewSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value def TorqueValue :> Real {
        attribute unit : String = "N·m";
    }
    value def ForceValue :> Real {
        attribute unit : "N";
    }
    value def LengthValue :> Real {
        attribute unit : String = "m";
    }
    value def HardnessValue :> Real {
        attribute unit : String = "HB";
    }
    value def RotationalSpeedValue :> Real {
        attribute unit : String = "rad/s";
    }
    value def AngleValue :> Real {
        attribute unit : String = "rad";
    }
    value def StressValue :> Real {
        attribute unit : String = "Pa";
    }
    value def MassValue :> Real {
        attribute unit : String = "kg";
    }

    // ---- Enumerations ----
    enum def HeadType { phillips; flathead; hex; torx; }
    enum def MaterialType { steel; aluminum; wood; plastic; brass; }
    enum def TipGeometry { pointed; flat; gimlet; selfDrilling; }

    // ---- Item definitions ----
    item def RotationalEnergy {
        attribute torque : TorqueValue;
        attribute speed : RotationalSpeedValue;
    }
    item def AxialForce {
        attribute magnitude : ForceValue;
    }
    item def ClampingForce {
        attribute magnitude : ForceValue;
    }

    // ---- Port definitions ----
    port def TorqueInputPort {
        in attribute appliedTorque : TorqueValue;
        in attribute rotationSpeed : RotationalSpeedValue;
    }
    port def RotationalEnergyOutPort {
        out energy : RotationalEnergy;
    }
    port def RotationalEnergyInPort {
        in energy : RotationalEnergy;
    }
    port def AxialForceOutPort {
        out force : AxialForce;
    }
    port def AxialForceInPort {
        in force : AxialForce;
    }
    port def ClampingForceOutPort {
        out force : ClampingForce;
    }
    port def MaterialInterfacePort {
        in attribute materialHardness : HardnessValue;
        in attribute materialThickness : LengthValue;
        in attribute materialType : MaterialType;
    }

    // ---- Part: Screw Head ----
    part def ScrewHead {
        attribute headType : HeadType = HeadType::phillips;
        attribute maxTorque : TorqueValue = 6.0;
        attribute driveRecessDepth : LengthValue = 0.004;
        port torqueIn : TorqueInputPort;
        port energyOut : RotationalEnergyOutPort;

        action transmitTorque {
            in appliedTorque : TorqueValue;
            in rotationSpeed : RotationalSpeedValue;
            out energy : RotationalEnergy;
            
            // Guard: torque must not exceed head capacity
            if appliedTorque <= maxTorque {
                assign energy.torque := appliedTorque;
                assign energy.speed := rotationSpeed;
            }
        }
    }

    // ---- Part: Threaded Shaft ----
    part def ThreadedShaft {
        attribute shaftLength : LengthValue = 0.050;
        attribute threadPitch : LengthValue = 0.0015;
        attribute majorDiameter : LengthValue = 0.0040;
        attribute minorDiameter : LengthValue = 0.0032;
        attribute helixAngle : AngleValue = 0.12;
        attribute frictionCoefficient : Real = 0.20;
        attribute tensileStrength : StressValue = 800.0e6;
        port energyIn : RotationalEnergyInPort;
        port materialInterface : MaterialInterfacePort;
        port forceOut : AxialForceOutPort;

        action convertRotationToLinear {
            in energy : RotationalEnergy;
            in materialHardness : HardnessValue;
            in materialThickness : LengthValue;
            out axialForce : AxialForce;
            attribute lead : LengthValue = threadPitch;
            attribute mechanicalAdvantage : Real = (2.0 * 3.14159 * majorDiameter / 2.0) / lead;
            attribute efficiency : Real = (mechanicalAdvantage - frictionCoefficient) / (mechanicalAdvantage + frictionCoefficient);
            
            assign axialForce.magnitude := energy.torque * efficiency * 2.0 * 3.14159 / lead;
        }
    }

    // ---- Part: Screw Tip ----
    part def ScrewTip {
        attribute tipGeometry : TipGeometry = TipGeometry::pointed;
        attribute tipAngle : AngleValue = 0.35;
        port forceIn : AxialForceInPort;
        port clampingForceOut : ClampingForceOutPort;

        action applyClampingForce {
            in axialForce : AxialForce;
            out clampingForce : ClampingForce;
            assign clampingForce.magnitude := axialForce.magnitude;
        }
    }

    // ---- Part: Workpiece ----
    part def Workpiece {
        attribute materialType : MaterialType = MaterialType::steel;
        attribute thickness : LengthValue = 0.012;
        attribute hardness : HardnessValue = 200.0;
        attribute yieldStrength : StressValue = 250.0e6;
        attribute mass : MassValue = 0.5;
        port materialInterface : MaterialInterfacePort {
            redefines in attribute materialHardness := hardness;
            redefines in attribute materialThickness := thickness;
            redefines in attribute materialType := materialType;
        }
        port clampingForceIn : ClampingForceOutPort;
    }

    // ---- Part: Tool ----
    part def Tool {
        attribute name : String = "PhillipsDriver";
        attribute maxOutputTorque : TorqueValue = 5.0;
        attribute nominalSpeed : RotationalSpeedValue = 10.0;
        port torqueOut : TorqueInputPort {
            redefines in attribute appliedTorque := maxOutputTorque;
            redefines in attribute rotationSpeed := nominalSpeed;
        }
    }

    // ---- Composite Part: Screw ----
    part def Screw {
        attribute designation : String = "M4x50_Phillips";
        part head : ScrewHead;
        part shaft : ThreadedShaft;
        part tip : ScrewTip;

        // Internal connections
        connect head.energyOut to shaft.energyIn {
            item energy : RotationalEnergy;
        }
        connect shaft.forceOut to tip.forceIn {
            item force : AxialForce;
        }

        // External ports
        port torqueIn : TorqueInputPort;
        port materialInterface : MaterialInterfacePort;
        port clampingForceOut : ClampingForceOutPort;

        connect torqueIn to head.torqueIn;
        connect materialInterface to shaft.materialInterface;
        connect tip.clampingForceOut to clampingForceOut;
    }

    // ---- State Machine: Screw Operation ----
    state def ScrewOperation {
        attribute targetClampingForce : ForceValue = 1200.0;
        attribute currentClampingForce : ForceValue = 0.0;
        attribute threadsEngaged : Boolean = false;
        attribute torqueApplied : TorqueValue = 0.0;

        entry; then idle;

        state idle {
            entry action { 
                assign currentClampingForce := 0.0; 
                assign threadsEngaged := false; 
                assign torqueApplied := 0.0; 
            }
        }

        state engaging {
            entry action { assign threadsEngaged := false; }
            do action { 
                // Threads begin to bite into material
                assign threadsEngaged := (torqueApplied > 0.5); 
            }
            exit action { assign threadsEngaged := true; }
        }

        state tightening {
            entry action { assign currentClampingForce := 0.0; }
            do action {
                // Clamping force ramps up as screw is driven further
                assign currentClampingForce := currentClampingForce + 50.0;
            }
        }

        state seated {
            entry action { 
                assign currentClampingForce := targetClampingForce; 
            }
        }

        transition idle_to_engaging
            first idle
            when (torqueApplied > 0.0)
            then engaging;

        transition engaging_to_tightening
            first engaging
            when (threadsEngaged == true)
            then tightening;

        transition tightening_to_seated
            first tightening
            when (currentClampingForce >= targetClampingForce)
            then seated;

        transition seated_to_idle
            first seated
            when (torqueApplied == 0.0 && currentClampingForce == 0.0)
            then idle;
    }

    // ---- Composite System ----
    part def ScrewFasteningSystem {
        attribute systemName : String = "StandardMechanicalScrewSystem";
        part tool : Tool;
        part screw : Screw;
        part workpiece : Workpiece;

        // Connect tool to screw head
        connect tool.torqueOut to screw.torqueIn;

        // Connect screw material interface to workpiece
        connect screw.materialInterface to workpiece.materialInterface;

        // Connect screw clamping force output to workpiece
        connect screw.clampingForceOut to workpiece.clampingForceIn;

        // Behavioral composition
        perform action operateScrew : ScrewOperation;
    }

    // ---- Requirements ----
    requirement def ClampingForceRequirement {
        attribute requiredForce : ForceValue = 1000.0;
        attribute safetyFactor : Real = 1.25;
        attribute maxSeparationLoad : ForceValue = 800.0;
        
        doc /* The screw system shall reliably and efficiently generate 
              sufficient clamping force to prevent the fastened workpieces 
              from separating under operational loads. */
        
        require constraint { 
            screw.tip.clampingForceOut.force.magnitude >= requiredForce 
        }
        require constraint { 
            currentClampingForce * safetyFactor >= maxSeparationLoad 
        }
    }

    requirement def TorqueEfficiencyRequirement {
        attribute minEfficiency : Real = 0.30;
        attribute maxInputTorque : TorqueValue = 5.0;
        
        doc /* The screw shall convert applied torque into axial clamping 
              force with adequate mechanical efficiency. */
        
        require constraint { 
            (screw.shaft.helixAngle > 0.0) && (screw.shaft.frictionCoefficient < 0.5) 
        }
    }

    requirement def MaterialCompatibilityRequirement {
        attribute minHardness : HardnessValue = 80.0;
        attribute maxHardness : HardnessValue = 400.0;
        attribute minThickness : LengthValue = 0.002;
        attribute maxThickness : LengthValue = 0.050;
        
        doc /* The screw system shall be compatible with workpiece materials 
              within specified hardness and thickness ranges. */
        
        require constraint { 
            workpiece.hardness >= minHardness && workpiece.hardness <= maxHardness 
        }
        require constraint { 
            workpiece.thickness >= minThickness && workpiece.thickness <= maxThickness 
        }
    }

    requirement def SeatingRequirement {
        attribute targetForce : ForceValue = 1200.0;
        attribute tolerance : ForceValue = 50.0;
        
        doc /* The screw shall reach a seated state when the desired 
              clamping force is achieved. */
        
        require constraint { 
            ScrewOperation.seated.currentClampingForce >= targetForce - tolerance 
        }
    }

    // ---- Verification actions ----
    verification verifyClampingForce {
        subject : ScrewFasteningSystem;
        objective { 
            doc /* Verify the system meets the clamping force requirement. */ 
        }
        method {
            assert subject.screw.tip.clampingForceOut.force.magnitude >= 1000.0;
        }
    }

    verification verifySeating {
        subject : ScrewFasteningSystem;
        objective { 
            doc /* Verify the screw reaches seated state. */ 
        }
        method {
            assert ScrewOperation.seated.isActive;
        }
    }
}
