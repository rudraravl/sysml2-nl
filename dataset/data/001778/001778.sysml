package FirstLawThermodynamicsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def InternalEnergyValue :> ISQ::energy;
    attribute def HeatTransferValue :> ISQ::energy;
    attribute def WorkTransferValue :> ISQ::energy;
    attribute def TemperatureValue :> ISQ::thermodynamicTemperature;
    attribute def PressureValue :> ISQ::pressure;
    attribute def VolumeValue :> ISQ::volume;
    attribute def HeatFlowRateValue :> ISQ::power;
    attribute def WorkRateValue :> ISQ::power;
    
    item def HeatPacket {
        attribute amount : HeatTransferValue;
        attribute flowRate : HeatFlowRateValue;
    }
    
    item def WorkPacket {
        attribute amount : WorkTransferValue;
        attribute rate : WorkRateValue;
    }
    
    port def ThermalPort {
        attribute temp : TemperatureValue;
        in item heatIn : HeatPacket;
        out item heatOut : HeatPacket;
    }
    
    port def MechanicalPort {
        attribute portPressure : PressureValue;
        in item workIn : WorkPacket;
        out item workOut : WorkPacket;
    }
    
    requirement def FirstLawRequirement {
        doc /* The change in internal energy of a closed system equals 
               the net heat added minus the net work done by the system. 
               dU = Q - W */
        
        subject system : ThermalSystem;
        
        require constraint {
            system.deltaInternalEnergy == 
                system.netHeatAdded - system.netWorkDone
        }
    }
    
    part def ThermalSystem {
        attribute initialInternalEnergy : InternalEnergyValue;
        attribute currentInternalEnergy : InternalEnergyValue;
        attribute deltaInternalEnergy : InternalEnergyValue;
        attribute netHeatAdded : HeatTransferValue;
        attribute netWorkDone : WorkTransferValue;
        attribute systemTemperature : TemperatureValue;
        attribute systemPressure : PressureValue;
        attribute systemVolume : VolumeValue;
        attribute thermalMass : Real;
        
        port thermalInput : ThermalPort;
        port thermalOutput : ThermalPort;
        port mechanicalOutput : MechanicalPort;
    }
    
    part def HighTemperatureReservoir {
        attribute reservoirTemperature : TemperatureValue;
        attribute heatCapacity : Real;
        
        port thermalOut : ThermalPort;
        
        action supplyHeat {
            out heatSupplied : HeatPacket;
        }
    }
    
    part def LowTemperatureReservoir {
        attribute reservoirTemperature : TemperatureValue;
        
        port thermalIn : ThermalPort;
        
        action absorbHeat {
            in heatReceived : HeatPacket;
        }
    }
    
    part def MechanicalLoad {
        attribute loadResistance : Real;
        
        port mechanicalIn : MechanicalPort;
        
        action consumeWork {
            in workReceived : WorkPacket;
        }
    }
    
    item def HeatAdditionSignal;
    item def ExpansionSignal;
    item def CoolingSignal;
    item def CompressionSignal;
    item def EquilibriumSignal;
    
    state def ThermalSystemState {
        entry action initialize {
            out initialTemp : TemperatureValue;
            out initialPressure : PressureValue;
            out initialEnergy : InternalEnergyValue;
        }
        
        state equilibrium {
            entry action maintainState;
        }
        
        transition equilibrium_to_heating
            first equilibrium
            accept HeatAdditionSignal
            then heating;
        
        state heating {
            entry action absorbHeat {
                in heatAdded : HeatTransferValue;
                out energyIncrease : InternalEnergyValue;
                out tempIncrease : TemperatureValue;
            }
            
            do action updateInternalEnergy {
                in currentEnergy : InternalEnergyValue;
                in heatFlow : HeatFlowRateValue;
                out newEnergy : InternalEnergyValue;
            }
        }
        
        transition heating_to_expansion
            first heating
            accept ExpansionSignal
            then expansion;
        
        state expansion {
            entry action doWork {
                in availableEnergy : InternalEnergyValue;
                out workPerformed : WorkTransferValue;
                out energyDecrease : InternalEnergyValue;
                out volumeIncrease : VolumeValue;
            }
            
            do action extractWork {
                in pressure : PressureValue;
                in volumeChange : VolumeValue;
                out workRate : WorkRateValue;
            }
        }
        
        transition expansion_to_cooling
            first expansion
            accept CoolingSignal
            then cooling;
        
        state cooling {
            entry action rejectHeat {
                in excessEnergy : InternalEnergyValue;
                out heatRejected : HeatTransferValue;
                out tempDecrease : TemperatureValue;
            }
        }
        
        transition cooling_to_compression
            first cooling
            accept CompressionSignal
            then compression;
        
        state compression {
            entry action compressGas {
                in workInput : WorkTransferValue;
                out energyIncrease : InternalEnergyValue;
                out volumeDecrease : VolumeValue;
                out pressureIncrease : PressureValue;
            }
        }
        
        transition compression_to_equilibrium
            first compression
            accept EquilibriumSignal
            then equilibrium;
    }
    
    action def ThermodynamicCycle {
        doc /* Represents a complete thermodynamic cycle implementing the first law:
               heat is absorbed, work is produced, and energy balance is maintained. */
        
        first start;
        then merge cycleLoop;
        
        action heatAbsorption {
            in heatSource : HeatPacket;
            out energyGained : InternalEnergyValue;
        }
        
        then action workProduction {
            in energyAvailable : InternalEnergyValue;
            out workProduced : WorkPacket;
            out energyConsumed : InternalEnergyValue;
        }
        
        then action heatRejection {
            in remainingEnergy : InternalEnergyValue;
            out wasteHeat : HeatPacket;
        }
        
        then action energyBalance {
            in initialEnergy : InternalEnergyValue;
            in heatIn : HeatTransferValue;
            in workOut : WorkTransferValue;
            in heatOut : HeatTransferValue;
            out finalEnergy : InternalEnergyValue;
        }
        
        then decide;
            if energyBalance.finalEnergy > 0.0 then continueCycle;
            if energyBalance.finalEnergy <= 0.0 then stopCycle;
        
        action continueCycle;
        then cycleLoop;
        
        action stopCycle;
        then done;
    }
    
    part heatEngine : ThermalSystem {
        doc /* A heat engine that converts thermal energy into mechanical work
               while conserving total energy according to the first law. */
        
        attribute :>> initialInternalEnergy = 8000.0 [SI::J];
        attribute :>> currentInternalEnergy = 8000.0 [SI::J];
        attribute :>> systemTemperature = 500.0 [SI::K];
        attribute :>> systemPressure = 300000.0 [SI::Pa];
        attribute :>> systemVolume = 0.08 [SI::'m^3'];
        attribute :>> thermalMass = 2.5;
        
        part hotReservoir : HighTemperatureReservoir {
            attribute :>> reservoirTemperature = 800.0 [SI::K];
            attribute :>> heatCapacity = 5000.0;
            
            action :>> supplyHeat {
                out :>> heatSupplied : HeatPacket {
                    attribute :>> amount = 12000.0 [SI::J];
                    attribute :>> flowRate = 3000.0 [SI::W];
                }
            }
        }
        
        part coldReservoir : LowTemperatureReservoir {
            attribute :>> reservoirTemperature = 300.0 [SI::K];
            
            action :>> absorbHeat {
                in :>> heatReceived : HeatPacket;
            }
        }
        
        part workLoad : MechanicalLoad {
            attribute :>> loadResistance = 150.0;
            
            action :>> consumeWork {
                in :>> workReceived : WorkPacket;
            }
        }
        
        private attribute hotHeatFlow : HeatPacket {
            attribute :>> amount = 12000.0 [SI::J];
            attribute :>> flowRate = 3000.0 [SI::W];
        }
        
        private attribute workOutputFlow : WorkPacket {
            attribute :>> amount = 4500.0 [SI::J];
            attribute :>> rate = 1125.0 [SI::W];
        }
        
        private attribute coldHeatFlow : HeatPacket {
            attribute :>> amount = 7500.0 [SI::J];
            attribute :>> flowRate = 1875.0 [SI::W];
        }
        
        action engineCycle : ThermodynamicCycle {
            action :>> heatAbsorption {
                in :>> heatSource : HeatPacket = hotHeatFlow;
                out :>> energyGained : InternalEnergyValue;
            }
            
            action :>> workProduction {
                in :>> energyAvailable : InternalEnergyValue = heatAbsorption.energyGained;
                out :>> workProduced : WorkPacket = workOutputFlow;
                out :>> energyConsumed : InternalEnergyValue;
            }
            
            action :>> heatRejection {
                in :>> remainingEnergy : InternalEnergyValue;
                out :>> wasteHeat : HeatPacket = coldHeatFlow;
            }
            
            action :>> energyBalance {
                in :>> initialEnergy : InternalEnergyValue = currentInternalEnergy;
                in :>> heatIn : HeatTransferValue = hotHeatFlow.amount;
                in :>> workOut : WorkTransferValue = workOutputFlow.amount;
                in :>> heatOut : HeatTransferValue = coldHeatFlow.amount;
                out :>> finalEnergy : InternalEnergyValue;
            }
        }
        
        state systemState : ThermalSystemState;
        
        perform action engineCycle;
        exhibit state systemState;
    }
    
    part thermodynamicContext : ThermalSystem :> heatEngine {
        doc /* Complete thermodynamic system demonstrating the first law:
               energy input as heat equals work output plus waste heat. */
        
        connection heatInput
            connect hotReservoir.thermalOut to thermalInput;
        
        connection workExtraction
            connect mechanicalOutput to workLoad.mechanicalIn;
        
        connection heatExhaust
            connect thermalOutput to coldReservoir.thermalIn;
        
        satisfy firstLawReq : FirstLawRequirement {
            subject engine = thermodynamicContext;
        }
        
        assert constraint energyConservation {
            hotHeatFlow.amount == workOutputFlow.amount + coldHeatFlow.amount
        }
        
        assert constraint efficiencyLimit {
            workOutputFlow.amount / hotHeatFlow.amount <= 
                (hotReservoir.reservoirTemperature - coldReservoir.reservoirTemperature) / 
                hotReservoir.reservoirTemperature
        }
    }
}
