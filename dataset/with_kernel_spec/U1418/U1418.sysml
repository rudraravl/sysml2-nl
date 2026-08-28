package NaturalGasDistributionSystem {
    private import ScalarValues::*;
    
    item def NaturalGas;
    
    attribute def PressureValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def VolumeValue :> Real;
    
    attribute def StartupComplete;
    attribute def HighDemand;
    attribute def MaintenanceScheduled;
    attribute def OverPressureAlarm;
    attribute def NormalDemand;
    attribute def MaintenanceComplete;
    attribute def EmergencyCleared;
    
    port def GasPort {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }
    
    part def HighPressureSupplyPoint {
        port gasOut : GasPort;
        attribute supplyPressure : PressureValue;
    }
    
    part def PressureRegulationStation {
        port gasIn : GasPort;
        port gasOut : GasPort;
        attribute outputPressure : PressureValue;
        perform action regulatePressure : RegulatePressure;
    }
    
    part def DistributionPipelineNetwork {
        port gasIn : GasPort;
        port gasOutResidential : GasPort;
        port gasOutCommercial : GasPort;
        port gasOutIndustrial : GasPort;
        port pressureTap : GasPort;
    }
    
    part def PressureMonitor {
        port gasIn : GasPort;
        attribute minSafePressure : PressureValue;
        attribute maxSafePressure : PressureValue;
        perform action monitorPressure : MonitorPressure;
    }
    
    part def SafetyValve {
        port gasIn : GasPort;
        port ventPort : GasPort;
        attribute criticalPressure : PressureValue;
        perform action ventExcessGas : VentExcessGas;
    }
    
    part def MeteringStation {
        port gasIn : GasPort;
        port gasOut : GasPort;
        attribute deliveryPressure : PressureValue;
        perform action measureVolume : MeasureVolume;
    }
    
    part def ResidentialMeteringStation :> MeteringStation;
    part def CommercialMeteringStation :> MeteringStation;
    part def IndustrialMeteringStation :> MeteringStation;
    
    part def EndUser {
        port gasIn : GasPort;
        attribute demandRate : FlowRateValue;
    }
    
    action def RegulatePressure {
        in gasIn : NaturalGas;
        in currentPressure : PressureValue;
        out gasOut : NaturalGas;
        out regulatedPressure : PressureValue;
    }
    
    action def MonitorPressure {
        in currentPressure : PressureValue;
        out warning : Boolean;
        out alarm : Boolean;
    }
    
    action def VentExcessGas {
        in currentPressure : PressureValue;
        out ventedGas : NaturalGas;
    }
    
    action def MeasureVolume {
        in gasIn : NaturalGas;
        out volumeConsumed : VolumeValue;
    }
    
    action def PerformSystemChecks;
    action def IncreaseFlowCapacity;
    action def PerformMaintenance;
    action def ActivateSafetyProtocols;
    
    state def SystemStates;
    
    requirement def PressureRegulationRequirement {
        doc
        /*
         * The pressure regulation station shall reduce inlet pressure
         * to a safe outlet pressure for local distribution.
         */
        attribute requiredOutputPressure : PressureValue;
    }
    
    requirement def SafetyRequirement {
        doc
        /*
         * The safety valve shall vent excess gas when system pressure
         * exceeds the critical set point.
         */
        attribute maxCriticalPressure : PressureValue;
    }
    
    part gasDistributionSystem {
        part highPressureSupply : HighPressureSupplyPoint;
        part regulationStation : PressureRegulationStation;
        part pipelineNetwork : DistributionPipelineNetwork;
        part pressureMonitor : PressureMonitor;
        part safetyValve : SafetyValve;
        part residentialMeter : ResidentialMeteringStation;
        part commercialMeter : CommercialMeteringStation;
        part industrialMeter : IndustrialMeteringStation;
        part residentialUser : EndUser;
        part commercialUser : EndUser;
        part industrialUser : EndUser;
        
        connect highPressureSupply.gasOut to regulationStation.gasIn;
        connect regulationStation.gasOut to pipelineNetwork.gasIn;
        connect pipelineNetwork.gasOutResidential to residentialMeter.gasIn;
        connect pipelineNetwork.gasOutCommercial to commercialMeter.gasIn;
        connect pipelineNetwork.gasOutIndustrial to industrialMeter.gasIn;
        connect residentialMeter.gasOut to residentialUser.gasIn;
        connect commercialMeter.gasOut to commercialUser.gasIn;
        connect industrialMeter.gasOut to industrialUser.gasIn;
        connect pipelineNetwork.pressureTap to pressureMonitor.gasIn;
        connect pipelineNetwork.pressureTap to safetyValve.gasIn;
        
        action performSystemChecks : PerformSystemChecks;
        action regulatePressure : RegulatePressure;
        action monitorPressure : MonitorPressure;
        action increaseFlowCapacity : IncreaseFlowCapacity;
        action performMaintenance : PerformMaintenance;
        action activateSafetyProtocols : ActivateSafetyProtocols;
        action ventExcessGas : VentExcessGas;
        
        exhibit state systemStates : SystemStates {
            entry; then startup;
            state startup {
                do performSystemChecks;
            }
            accept StartupComplete then normalOperation;
            state normalOperation {
                entry regulatePressure;
                do monitorPressure;
            }
            accept HighDemand then peakDemand;
            accept MaintenanceScheduled then maintenance;
            accept OverPressureAlarm then emergency;
            state peakDemand {
                entry increaseFlowCapacity;
                do regulatePressure;
            }
            accept NormalDemand then normalOperation;
            state maintenance {
                do performMaintenance;
            }
            accept MaintenanceComplete then normalOperation;
            state emergency {
                entry activateSafetyProtocols;
                do ventExcessGas;
            }
            accept EmergencyCleared then normalOperation;
        }
    }
}
