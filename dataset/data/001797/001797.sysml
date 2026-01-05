package InflatableHabitatSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DeployCommand;
    attribute def StowCommand;
    attribute def EmergencyVent;
    
    port def AirSupplyPort {
        in attribute airFlow : ISQ::VolumeFlowRateValue;
        in attribute supplyPressure : ISQ::PressureValue;
    }
    
    port def SensorPort {
        out attribute measuredPressure : ISQ::PressureValue;
        out attribute measuredVolume : ISQ::VolumeValue;
    }
    
    port def CommandPort {
        in attribute deployCmd : DeployCommand;
        in attribute stowCmd : StowCommand;
        in attribute emergencyCmd : EmergencyVent;
        out attribute status : SystemStatus;
    }
    
    attribute def SystemStatus {
        attribute isDeploying : Boolean;
        attribute isStowed : Boolean;
        attribute isOperational : Boolean;
        attribute pressureNominal : Boolean;
    }
    
    part def CompressorUnit {
        port airOutput : AirSupplyPort;
        attribute maxFlowRate : ISQ::VolumeFlowRateValue;
        attribute maxOutputPressure : ISQ::PressureValue;
        
        action def GenerateAirFlow {
            in targetFlow : ISQ::VolumeFlowRateValue;
            out actualFlow : ISQ::VolumeFlowRateValue;
            out outputPressure : ISQ::PressureValue;
        }
    }
    
    part def PressureMonitor {
        port sensorInterface : SensorPort;
        attribute measurementAccuracy : Real;
        
        action def ReadPressure {
            in structureState : StructureState;
            out pressure : ISQ::PressureValue;
            out volume : ISQ::VolumeValue;
        }
    }
    
    part def FlowController {
        port commandInterface : CommandPort;
        attribute responseTime : ISQ::TimeValue;
        
        action def AdjustFlow {
            in currentPressure : ISQ::PressureValue;
            in targetPressure : ISQ::PressureValue;
            out flowAdjustment : ISQ::VolumeFlowRateValue;
        }
    }
    
    part def InflatableStructure {
        attribute maxOperatingPressure : ISQ::PressureValue;
        attribute minOperatingPressure : ISQ::PressureValue;
        attribute designVolume : ISQ::VolumeValue;
        attribute currentPressure : ISQ::PressureValue;
        attribute currentVolume : ISQ::VolumeValue;
        attribute fabricMaterial : String;
        attribute structuralRating : Real;
    }
    
    attribute def StructureState {
        attribute pressure : ISQ::PressureValue;
        attribute volume : ISQ::VolumeValue;
        attribute integrity : Real;
    }
    
    action def MonitorStructure {
        in structure : StructureState;
        out pressure : ISQ::PressureValue;
        out volume : ISQ::VolumeValue;
        out isNominal : Boolean;
    }
    
    action def InflateStructure {
        in airFlow : ISQ::VolumeFlowRateValue;
        in currentState : StructureState;
        out newState : StructureState;
    }
    
    action def DeflateStructure {
        in ventRate : ISQ::VolumeFlowRateValue;
        in currentState : StructureState;
        out newState : StructureState;
    }
    
    action def VerifySafety {
        in structureState : StructureState;
        in maxPressure : ISQ::PressureValue;
        in minPressure : ISQ::PressureValue;
        out safetyStatus : Boolean;
    }
    
    action def DeploymentControl {
        in targetPressure : ISQ::PressureValue;
        in maxAllowedPressure : ISQ::PressureValue;
        in minAllowedPressure : ISQ::PressureValue;
        in nominalFlowRate : ISQ::VolumeFlowRateValue;
        out finalPressure : ISQ::PressureValue;
        out deploymentSuccess : Boolean;
        
        first start;
        then merge controlLoop;
        
        then action monitor : MonitorStructure {
            in structure : StructureState;
            out pressure : ISQ::PressureValue;
            out volume : ISQ::VolumeValue;
            out isNominal : Boolean;
        }
        
        then action safety : VerifySafety {
            in structureState : StructureState;
            in maxPressure = maxAllowedPressure;
            in minPressure = minAllowedPressure;
            out safetyStatus : Boolean;
        }
        
        then decide;
            if not safety.safetyStatus then emergencyVenting;
            if safety.safetyStatus and monitor.pressure < targetPressure then continueInflation;
            if safety.safetyStatus and monitor.pressure >= targetPressure then holdPressure;
        
        action continueInflation : InflateStructure {
            in airFlow = nominalFlowRate;
            in currentState : StructureState;
            out newState : StructureState;
        }
        then controlLoop;
        
        action emergencyVenting : DeflateStructure {
            in ventRate : ISQ::VolumeFlowRateValue;
            in currentState : StructureState;
            out newState : StructureState;
        }
        then done;
        
        action holdPressure {
            out stabilizedPressure : ISQ::PressureValue;
        }
        then done;
    }
    
    part def InflatableHabitat {
        attribute operationalPressure : ISQ::PressureValue;
        attribute deploymentTime : ISQ::TimeValue;
        attribute safetyFactor : Real;
        
        part compressor : CompressorUnit {
            port airOut : AirSupplyPort;
        }
        
        part monitor : PressureMonitor {
            port sensorOut : SensorPort;
        }
        
        part flowControl : FlowController {
            port cmdInterface : CommandPort;
        }
        
        part structure : InflatableStructure;
        
        connect compressor.airOut to structure;
        connect structure to monitor.sensorOut;
        connect flowControl.cmdInterface to structure;
        
        perform action deployHabitat : DeploymentControl {
            in targetPressure = operationalPressure;
            in maxAllowedPressure = structure.maxOperatingPressure;
            in minAllowedPressure = structure.minOperatingPressure;
            in nominalFlowRate : ISQ::VolumeFlowRateValue;
            out finalPressure : ISQ::PressureValue;
            out deploymentSuccess : Boolean;
        }
    }
    
    state def HabitatLifecycle {
        entry; then stowed;
        
        state stowed;
        
        accept deployCmd : DeployCommand
            then deploying;
        
        state deploying {
            entry perform compressor.GenerateAirFlow;
            do perform deployHabitat;
        }
        
        transition deploying to operational
            when structure.currentPressure >= operationalPressure;
        
        state operational {
            do perform monitor.ReadPressure;
        }
        
        accept emergencyCmd : EmergencyVent
            first from operational
            then venting;
        
        accept stowCmd : StowCommand
            first from operational
            then stowing;
        
        state venting {
            do perform DeflateStructure;
        }
        
        transition venting to stowed
            when structure.currentPressure <= structure.minOperatingPressure;
        
        state stowing {
            do perform DeflateStructure;
        }
        
        transition stowing to stowed
            when structure.currentPressure <= 0.1[SI::kPa];
    }
    
    requirement def SafetyRequirement {
        doc /* The inflatable habitat shall maintain internal pressure within safe operating limits at all times. */
        
        subject habitat : InflatableHabitat;
        
        require constraint {
            habitat.structure.currentPressure <= habitat.structure.maxOperatingPressure
        }
        
        require constraint {
            habitat.structure.currentPressure >= habitat.structure.minOperatingPressure or
            habitat.structure.currentPressure == 0.0[SI::kPa]
        }
    }
    
    requirement def DeploymentRequirement {
        doc /* The inflatable habitat shall deploy to operational pressure within specified time limit. */
        
        subject habitat : InflatableHabitat;
        
        attribute maxDeploymentTime : ISQ::TimeValue;
        
        require constraint {
            habitat.deploymentTime <= maxDeploymentTime
        }
    }
    
    requirement def StructuralRequirement {
        doc /* The inflatable structure shall maintain structural integrity throughout operational lifecycle. */
        
        subject structure : InflatableStructure;
        
        require constraint {
            structure.structuralRating >= 0.98
        }
    }
    
    requirement def PrimaryFunction {
        doc /* The inflatable habitat system shall provide a pressurized, habitable volume by deploying an inflatable structure to operational pressure and maintaining that pressure throughout the mission. */
        
        subject system : InflatableHabitat;
        
        require safetyReq : SafetyRequirement;
        require deployReq : DeploymentRequirement;
        require structuralReq : StructuralRequirement;
    }
    
    part habitatSystem : InflatableHabitat {
        :>> operationalPressure = 101.3[SI::kPa];
        :>> deploymentTime = 180.0[SI::s];
        :>> safetyFactor = 1.5;
        
        part :>> compressor {
            :>> maxFlowRate = 50.0[SI::m^3/SI::s];
            :>> maxOutputPressure = 150.0[SI::kPa];
        }
        
        part :>> structure {
            :>> maxOperatingPressure = 120.0[SI::kPa];
            :>> minOperatingPressure = 95.0[SI::kPa];
            :>> designVolume = 200.0[SI::m^3];
            :>> fabricMaterial = "Kevlar-reinforced polymer";
            :>> structuralRating = 0.99;
        }
        
        perform state HabitatLifecycle;
    }
    
    satisfy PrimaryFunction by habitatSystem;
}
