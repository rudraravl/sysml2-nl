package AC_Power_Distribution_System {
    import ScalarValues::*;

    attribute def Voltage :> Real { unit "V"; }
    attribute def Current :> Real { unit "A"; }
    attribute def Frequency :> Real { unit "Hz"; }
    attribute def Power :> Real { unit "W"; }

    item def AC_Power {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequency : Frequency;
        attribute activePower : Power;
    }

    port def AC_PowerPort {
        out item power : AC_Power;
    }
    
    port def MonitoringPort {
        out item measuredVoltage : Voltage;
        out item measuredCurrent : Current;
        out item measuredFrequency : Frequency;
    }
    
    port def TripPort {
        out item tripSignal : Boolean;
    }

    port def AdjustPort {
        in item adjustSignal : Real;
    }

    part def PowerGenerator {
        port powerOut : AC_PowerPort;
        port adjustIn : AdjustPort;
        attribute nominalVoltage : Voltage = 13800 ["V"];
        attribute nominalFrequency : Frequency = 60 ["Hz"];
        attribute outputPower : Power = 5000000 ["W"];
        
        action def generatePower {
            out generatedPower : AC_Power;
        }
    }

    part def StepUpTransformer {
        port primaryIn : AC_PowerPort;
        port secondaryOut : AC_PowerPort;
        attribute turnsRatio : Real = 10.0;
    }

    part def TransmissionLine {
        port lineIn : AC_PowerPort;
        port lineOut : AC_PowerPort;
        port monitorOut : MonitoringPort;
        port tripIn : TripPort;
        attribute length : Real = 100;
        attribute resistance : Real = 0.1;
    }

    part def ProtectionRelay {
        port monitorIn : MonitoringPort;
        port tripOut : TripPort;
        attribute faultThreshold : Current = 1000 ["A"];
        
        state def RelayBehavior {
            state Monitoring;
            state Tripped;
            transition monitoring_to_tripped 
                first Monitoring 
                if monitorIn.measuredCurrent > faultThreshold 
                then Tripped;
            transition tripped_to_monitoring 
                first Tripped 
                if monitorIn.measuredCurrent <= faultThreshold 
                then Monitoring;
        }
    }

    part def StepDownTransformer {
        port primaryIn : AC_PowerPort;
        port secondaryOut : AC_PowerPort;
        attribute turnsRatio : Real = 0.1;
    }

    part def VoltageRegulator {
        port inputPort : AC_PowerPort;
        port outputPort : AC_PowerPort;
        attribute targetVoltage : Voltage = 12000 ["V"];
    }

    part def DistributionLoad {
        port inputPort : AC_PowerPort;
        attribute demand : Power = 5000000 ["W"];
    }

    part def ACPowerDistributionSystem {
        port gridMonitor : MonitoringPort;
        
        part generator : PowerGenerator;
        part stepUp : StepUpTransformer;
        part transmissionLine : TransmissionLine;
        part relay : ProtectionRelay;
        part stepDown : StepDownTransformer;
        part regulator : VoltageRegulator;
        part load : DistributionLoad;

        connect generator.powerOut to stepUp.primaryIn;
        connect stepUp.secondaryOut to transmissionLine.lineIn;
        connect transmissionLine.monitorOut to relay.monitorIn;
        connect relay.tripOut to transmissionLine.tripIn;
        connect transmissionLine.lineOut to stepDown.primaryIn;
        connect stepDown.secondaryOut to regulator.inputPort;
        connect regulator.outputPort to load.inputPort;
        
        connect transmissionLine.monitorOut to gridMonitor;

        state def SystemOperation {
            state Normal;
            state LoadBalancing;
            state Faulted;
            
            transition normal_to_balancing 
                first Normal 
                if gridMonitor.measuredVoltage < 13000 ["V"] or gridMonitor.measuredFrequency < 59.5 ["Hz"] 
                then LoadBalancing;
                
            transition balancing_to_normal 
                first LoadBalancing 
                if gridMonitor.measuredVoltage >= 13000 ["V"] and gridMonitor.measuredFrequency >= 59.5 ["Hz"] 
                then Normal;
                
            transition normal_to_faulted 
                first Normal 
                if relay.tripOut.tripSignal == true 
                then Faulted;
                
            transition faulted_to_normal 
                first Faulted 
                if relay.tripOut.tripSignal == false 
                then Normal;
        }

        action def loadBalancingProcess {
            in currentVoltage : Voltage;
            in currentFrequency : Frequency;
            out adjustmentFactor : Real;
        }
    }

    requirement def ConsistentVoltageFrequency {
        subject system : ACPowerDistributionSystem;
        requirement {
            system.gridMonitor.measuredVoltage >= 11000 ["V"] and
            system.gridMonitor.measuredVoltage <= 14000 ["V"] and
            system.gridMonitor.measuredFrequency >= 59.9 ["Hz"] and
            system.gridMonitor.measuredFrequency <= 60.1 ["Hz"];
        }
    }

    requirement def RapidFaultProtection {
        subject relay : ProtectionRelay;
        requirement {
            relay.tripOut.tripSignal == true implies relay.monitorIn.measuredCurrent > relay.faultThreshold;
        }
    }

    requirement def HighPowerQuality {
        subject system : ACPowerDistributionSystem;
        requirement {
            system.gridMonitor.measuredFrequency >= 59.9 ["Hz"] and
            system.gridMonitor.measuredFrequency <= 60.1 ["Hz"];
        }
    }
}
