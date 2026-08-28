package HydraulicRamSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def HydraulicPressure :> ISQ::PressureValue;
    attribute def HydraulicFlowRate :> ISQ::VolumeFlowRateValue;
    attribute def LinearForce :> ISQ::ForceValue;
    attribute def LinearPosition :> ISQ::LengthValue;
    attribute def LinearVelocity :> ISQ::SpeedValue;
    attribute def PistonArea :> ISQ::AreaValue;
    attribute def StrokeLength :> ISQ::LengthValue;
    
    item def HydraulicFluid {
        attribute pressure : HydraulicPressure;
        attribute flowRate : HydraulicFlowRate;
        attribute viscosity : ISQ::DynamicViscosityValue;
    }
    
    port def HydraulicPort {
        in item fluidIn : HydraulicFluid;
        out item fluidOut : HydraulicFluid;
        attribute pressure : HydraulicPressure;
        attribute flowRate : HydraulicFlowRate;
    }
    
    port def ForceOutputPort {
        out attribute force : LinearForce;
        out attribute position : LinearPosition;
        out attribute velocity : LinearVelocity;
    }
    
    part def Cylinder {
        attribute bore : ISQ::LengthValue;
        attribute pistonArea : PistonArea;
        attribute maxPressure : HydraulicPressure;
        port capEnd : HydraulicPort;
        port rodEnd : HydraulicPort;
    }
    
    part def Piston {
        attribute position : LinearPosition;
        attribute velocity : LinearVelocity;
        attribute area : PistonArea;
        attribute mass : ISQ::MassValue;
    }
    
    part def PistonRod {
        attribute diameter : ISQ::LengthValue;
        attribute length : ISQ::LengthValue;
        attribute outputForce : LinearForce;
        port mechanicalOutput : ForceOutputPort;
    }
    
    action def ExtendRam {
        in capPressure : HydraulicPressure;
        in rodPressure : HydraulicPressure;
        in pistonArea : PistonArea;
        in rodArea : PistonArea;
        in currentPosition : LinearPosition;
        in maxStroke : StrokeLength;
        out newPosition : LinearPosition;
        out newVelocity : LinearVelocity;
        out outputForce : LinearForce;
    }
    
    action def RetractRam {
        in capPressure : HydraulicPressure;
        in rodPressure : HydraulicPressure;
        in pistonArea : PistonArea;
        in rodArea : PistonArea;
        in currentPosition : LinearPosition;
        out newPosition : LinearPosition;
        out newVelocity : LinearVelocity;
    }
    
    action def CalculateForce {
        in capPressure : HydraulicPressure;
        in rodPressure : HydraulicPressure;
        in pistonArea : PistonArea;
        in rodArea : PistonArea;
        out netForce : LinearForce;
    }
    
    action def HoldPosition {
        in currentPosition : LinearPosition;
        in lockingPressure : HydraulicPressure;
        out maintainedPosition : LinearPosition;
    }
    
    attribute def ExtendCommand;
    attribute def RetractCommand;
    
    state def RamOperationControl {
        entry; then retracted;
        
        state retracted;
        
        transition retracted
            accept extendCommand : ExtendCommand
            then extending;
            
        state extending;
        
        transition extending
            if currentPosition >= targetStroke
            then extended;
            
        state extended;
        
        transition extended
            accept retractCommand : RetractCommand
            then retracting;
            
        state retracting;
        
        transition retracting
            if currentPosition <= 0.0
            then retracted;
    }
    
    requirement def ForceCapabilityRequirement {
        doc /* The hydraulic ram shall generate sufficient output force to overcome the rated load based on supply pressure and effective piston area. */
        
        subject ram : HydraulicRam;
        
        require constraint {
            ram.rod.outputForce >= ram.ratedLoad
        }
    }
    
    requirement def StrokeLengthRequirement {
        doc /* The hydraulic ram shall provide a stroke length that meets or exceeds the specified operational stroke requirement. */
        
        subject ram : HydraulicRam;
        
        require constraint {
            ram.maxStroke >= ram.requiredStroke
        }
    }
    
    requirement def PressureRatingRequirement {
        doc /* The hydraulic ram cylinder shall withstand the maximum system pressure without failure or leakage. */
        
        subject ram : HydraulicRam;
        
        require constraint {
            ram.cylinder.maxPressure >= ram.maxSystemPressure
        }
    }
    
    part def HydraulicRam {
        attribute maxStroke : StrokeLength;
        attribute requiredStroke : StrokeLength;
        attribute ratedLoad : LinearForce;
        attribute maxSystemPressure : HydraulicPressure;
        attribute efficiency : Real;
        
        port supplyPort : HydraulicPort;
        port returnPort : HydraulicPort;
        port loadPort : ForceOutputPort;
        
        part cylinder : Cylinder {
            port redefines capEnd;
            port redefines rodEnd;
        }
        
        part piston : Piston;
        part rod : PistonRod;
        
        connect supplyPort to cylinder.capEnd;
        connect returnPort to cylinder.rodEnd;
        connect rod.mechanicalOutput to loadPort;
        
        bind piston.area = cylinder.pistonArea;
        
        perform action calculateOutputForce : CalculateForce {
            in capPressure = cylinder.capEnd.pressure;
            in rodPressure = cylinder.rodEnd.pressure;
            in pistonArea = piston.area;
            in rodArea = 0.0;
            out netForce;
        }
        
        bind rod.outputForce = calculateOutputForce.netForce;
        
        perform action operateRam {
            first start;
            
            then action initialize {
                assign piston.position := 0.0;
                assign piston.velocity := 0.0;
            }
            
            then merge controlLoop;
            
            then action control : RamOperationControl;
            
            then controlLoop;
        }
    }
    
    requirement primaryFunction {
        doc /* The primary function of the hydraulic ram system is to convert hydraulic pressure from a fluid power source into controlled linear mechanical force and motion to actuate an external load through a specified stroke length. */
        
        require forceCapability : ForceCapabilityRequirement;
        require strokeCapability : StrokeLengthRequirement;
        require pressureRating : PressureRatingRequirement;
    }
    
    part hydraulicActuator : HydraulicRam {
        :>> maxStroke = 500.0;
        :>> requiredStroke = 450.0;
        :>> ratedLoad = 50000.0;
        :>> maxSystemPressure = 20000000.0;
        :>> efficiency = 0.92;
        
        part redefines cylinder {
            :>> bore = 0.100;
            :>> pistonArea = 0.00785;
            :>> maxPressure = 21000000.0;
        }
        
        part redefines piston {
            :>> area = 0.00785;
            :>> mass = 2.5;
        }
        
        part redefines rod {
            :>> diameter = 0.050;
            :>> length = 0.550;
        }
        
        satisfy forceReq : ForceCapabilityRequirement {
            subject hydraulicActuator;
        }
        
        satisfy strokeReq : StrokeLengthRequirement {
            subject hydraulicActuator;
        }
        
        satisfy pressureReq : PressureRatingRequirement {
            subject hydraulicActuator;
        }
    }
}
