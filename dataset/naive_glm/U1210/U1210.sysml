package SmartGrid {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types =====
    
    value def Power :> Real {
        unit 'kW';
    }
    
    value def Energy :> Real {
        unit 'kWh';
    }
    
    value def Voltage :> Real {
        unit 'kV';
    }
    
    value def Frequency :> Real {
        unit 'Hz';
    }
    
    value def StateOfCharge :> Real {
        unit '%';
    }
    
    value def TimeStamp :> Real {
        unit 's';
    }
    
    enum def ConsumerPriority {
        critical;
        high;
        low;
    }
    
    enum def GridHealthState {
        stable;
        overloaded;
        underloaded;
        critical;
    }
    
    enum def ConsumerType {
        industrial;
        commercial;
        residential;
    }
    
    // ===== Item Types =====
    
    item def PowerFlow {
        ref power : Power;
        ref voltage : Voltage;
        ref frequency : Frequency;
    }
    
    item def MeterReading {
        ref demand : Power;
        ref timestamp : TimeStamp;
        ref consumerId : String;
    }
    
    item def GenerationReport {
        ref output : Power;
        ref sourceId : String;
        ref timestamp : TimeStamp;
    }
    
    item def StorageReport {
        ref charge : StateOfCharge;
        ref available : Power;
        ref timestamp : TimeStamp;
    }
    
    item def ControlCommand {
        ref targetId : String;
        ref action : String;
        ref value : Power;
    }
    
    // ===== Port Definitions =====
    
    port def PowerPort {
        out powerFlow : PowerFlow;
    }
    
    port def BidirectionalPowerPort {
        in powerIn : PowerFlow;
        out powerOut : PowerFlow;
    }
    
    port def DataPort {
        in readings : MeterReading;
        in genReports : GenerationReport;
        in storageReports : StorageReport;
        out commands : ControlCommand;
    }
    
    // ===== Generators =====
    
    part def PowerGenerator {
        port powerOut : PowerPort;
        attribute maxOutput : Power;
        attribute currentOutput : Power;
        
        exhibit state generationBehavior {
            entry; then generating;
            
            state generating;
            
            transition from generating to generating
                when currentOutput < maxOutput
                do { currentOutput = currentOutput + 100[kW]; }
            ;
        }
    }
    
    part def SolarFarm :> PowerGenerator {
        attribute maxOutput = 5000[kW];
        attribute currentOutput = 0[kW];
        
        exhibit state solarBehavior {
            entry; then active;
            state active;
            transition from active to active
                do { currentOutput = currentOutput + 50[kW]; }
            ;
        }
    }
    
    part def WindTurbine :> PowerGenerator {
        attribute maxOutput = 3000[kW];
        attribute currentOutput = 0[kW];
        
        exhibit state windBehavior {
            entry; then spinning;
            state spinning;
            transition from spinning to spinning
                do { currentOutput = currentOutput + 30[kW]; }
            ;
        }
    }
    
    part def NaturalGasPlant :> PowerGenerator {
        attribute maxOutput = 10000[kW];
        attribute currentOutput = 5000[kW];
        
        exhibit state gasBehavior {
            entry; then baseload;
            state baseload;
            state rampedDown;
            
            transition from baseload to rampedDown
                when currentOutput > 2000[kW]
                do { currentOutput = currentOutput - 500[kW]; }
            ;
            transition from rampedDown to baseload
                when currentOutput < maxOutput
                do { currentOutput = currentOutput + 500[kW]; }
            ;
        }
    }
    
    // ===== Battery Storage =====
    
    part def BatteryStorage {
        port powerPort : BidirectionalPowerPort;
        port dataPort : DataPort;
        
        attribute capacity : Energy = 20000[kWh];
        attribute chargeLevel : StateOfCharge = 50[%];
        attribute maxChargeRate : Power = 2000[kW];
        attribute maxDischargeRate : Power = 2000[kW];
        
        exhibit state storageBehavior {
            entry; then idle;
            
            state idle;
            state charging;
            state discharging;
            
            transition from idle to charging
                when chargeLevel < 100[%]
                do { chargeLevel = chargeLevel + 1[%]; }
            ;
            transition from charging to idle
                when chargeLevel >= 100[%]
            ;
            transition from idle to discharging
                when chargeLevel > 0[%]
                do { chargeLevel = chargeLevel - 1[%]; }
            ;
            transition from discharging to idle
                when chargeLevel <= 0[%]
            ;
        }
    }
    
    // ===== Transmission and Substations =====
    
    part def TransmissionLine {
        port input : PowerPort;
        port output : PowerPort;
        attribute capacity : Power = 20000[kW];
        attribute currentLoad : Power = 0[kW];
        attribute voltage : Voltage = 230[kV];
    }
    
    part def Substation {
        port highSide : PowerPort;
        port lowSide : PowerPort;
        attribute inputVoltage : Voltage;
        attribute outputVoltage : Voltage;
        attribute capacity : Power;
        attribute currentLoad : Power = 0[kW];
        
        exhibit state substationBehavior {
            entry; then operating;
            state operating;
            state overloaded;
            
            transition from operating to overloaded
                when currentLoad > capacity
            ;
            transition from overloaded to operating
                when currentLoad <= capacity
            ;
        }
    }
    
    part def PrimarySubstation :> Substation {
        attribute inputVoltage = 230[kV];
        attribute outputVoltage = 69[kV];
        attribute capacity = 15000[kW];
    }
    
    part def SecondarySubstation :> Substation {
        attribute inputVoltage = 69[kV];
        attribute outputVoltage = 12[kV];
        attribute capacity = 5000[kW];
    }
    
    // ===== Consumers =====
    
    part def SmartMeter {
        port dataPort : DataPort;
        port powerPort : BidirectionalPowerPort;
        attribute demand : Power = 0[kW];
        attribute consumerId : String;
        
        exhibit state metering {
            entry; then measuring;
            state measuring;
            transition from measuring to measuring
                do { demand = demand + 10[kW]; }
            ;
        }
    }
    
    part def Consumer {
        port powerPort : BidirectionalPowerPort;
        part smartMeter : SmartMeter;
        attribute type : ConsumerType;
        attribute priority : ConsumerPriority;
        attribute demand : Power;
        attribute powerSupplied : Power;
        attribute isShed : Boolean = false;
        
        exhibit state consumerBehavior {
            entry; then powered;
            
            state powered;
            state shed;
            
            transition from powered to shed
                when isShed == true
                do { powerSupplied = 0[kW]; }
            ;
            transition from shed to powered
                when isShed == false
                do { powerSupplied = demand; }
            ;
        }
    }
    
    part def IndustrialConsumer :> Consumer {
        attribute type = ConsumerType::industrial;
        attribute priority = ConsumerPriority::critical;
        attribute demand = 2000[kW];
    }
    
    part def CommercialConsumer :> Consumer {
        attribute type = ConsumerType::commercial;
        attribute priority = ConsumerPriority::high;
        attribute demand = 800[kW];
    }
    
    part def ResidentialConsumer :> Consumer {
        attribute type = ConsumerType::residential;
        attribute priority = ConsumerPriority::low;
        attribute demand = 200[kW];
    }
    
    // ===== Grid Control Center =====
    
    part def GridControlCenter {
        port dataPort : DataPort;
        
        attribute gridState : GridHealthState = GridHealthState::stable;
        attribute totalDemand : Power = 0[kW];
        attribute totalSupply : Power = 0[kW];
        attribute batteryCharge : StateOfCharge = 50[%];
        
        exhibit state controlLoop {
            entry; then monitoring;
            
            state monitoring;
            state optimizing;
            state loadShedding;
            state chargingBatteries;
            state rampingDownGas;
            
            transition from monitoring to optimizing
                when gridState == GridHealthState::stable
            ;
            transition from optimizing to monitoring
                do { gridState = GridHealthState::stable; }
            ;
            transition from monitoring to loadShedding
                when totalDemand > totalSupply
                do { gridState = GridHealthState::overloaded; }
            ;
            transition from loadShedding to monitoring
                when totalDemand <= totalSupply
                do { gridState = GridHealthState::stable; }
            ;
            transition from monitoring to chargingBatteries
                when totalSupply > totalDemand
                do { gridState = GridHealthState::underloaded; }
            ;
            transition from chargingBatteries to rampingDownGas
                when batteryCharge < 100[%]
            ;
            transition from rampingDownGas to monitoring
                when totalSupply <= totalDemand
                do { gridState = GridHealthState::stable; }
            ;
            transition from monitoring to monitoring
                when totalDemand > totalSupply * 1.5
                do { gridState = GridHealthState::critical; }
            ;
        }
        
        action def optimizeGeneration {
            in renewablePriority : Boolean = true;
            // Prioritize renewable sources, adjust gas plant output
        }
        
        action def shedLoad {
            in lowPriorityConsumers : Consumer[*];
            // Reduce power to low-priority consumers
        }
        
        action def chargeBatteries {
            in surplus : Power;
            // Direct surplus energy to battery storage
        }
        
        action def rampDownGas {
            in gasPlant : NaturalGasPlant;
            // Reduce natural gas plant output
        }
    }
    
    // ===== Smart Grid System =====
    
    part def SmartGridSystem {
        // Generators
        part solarFarm1 : SolarFarm;
        part solarFarm2 : SolarFarm;
        part windTurbine1 : WindTurbine;
        part windTurbine2 : WindTurbine;
        part windTurbine3 : WindTurbine;
        part gasPlant : NaturalGasPlant;
        
        // Storage
        part batteryStorage1 : BatteryStorage;
        part batteryStorage2 : BatteryStorage;
        
        // Transmission
        part mainTransmissionLine : TransmissionLine;
        part primarySubstation1 : PrimarySubstation;
        part primarySubstation2 : PrimarySubstation;
        part secondarySubstation1 : SecondarySubstation;
        part secondarySubstation2 : SecondarySubstation;
        part secondarySubstation3 : SecondarySubstation;
        
        // Consumers
        part industrialConsumer1 : IndustrialConsumer;
        part industrialConsumer2 : IndustrialConsumer;
        part commercialConsumer1 : CommercialConsumer;
        part commercialConsumer2 : CommercialConsumer;
        part commercialConsumer3 : CommercialConsumer;
        part residentialConsumer1 : ResidentialConsumer;
        part residentialConsumer2 : ResidentialConsumer;
        part residentialConsumer3 : ResidentialConsumer;
        part residentialConsumer4 : ResidentialConsumer;
        
        // Control Center
        part controlCenter : GridControlCenter;
        
        // Connections from generators to transmission
        connect solarFarm1.powerOut to mainTransmissionLine.input;
        connect solarFarm2.powerOut to mainTransmissionLine.input;
        connect windTurbine1.powerOut to mainTransmissionLine.input;
        connect windTurbine2.powerOut to mainTransmissionLine.input;
        connect windTurbine3.powerOut to mainTransmissionLine.input;
        connect gasPlant.powerOut to mainTransmissionLine.input;
        
        // Battery storage connections
        connect batteryStorage1.powerPort to mainTransmissionLine.input;
        connect batteryStorage2.powerPort to mainTransmissionLine.input;
        
        // Transmission to primary substations
        connect mainTransmissionLine.output to primarySubstation1.highSide;
        connect mainTransmissionLine.output to primarySubstation2.highSide;
        
        // Primary to secondary substations
        connect primarySubstation1.lowSide to secondarySubstation1.highSide;
        connect primarySubstation1.lowSide to secondarySubstation2.highSide;
        connect primarySubstation2.lowSide to secondarySubstation3.highSide;
        
        // Secondary substations to consumers
        connect secondarySubstation1.lowSide to industrialConsumer1.powerPort;
        connect secondarySubstation1.lowSide to industrialConsumer2.powerPort;
        connect secondarySubstation2.lowSide to commercialConsumer1.powerPort;
        connect secondarySubstation2.lowSide to commercialConsumer2.powerPort;
        connect secondarySubstation2.lowSide to commercialConsumer3.powerPort;
        connect secondarySubstation3.lowSide to residentialConsumer1.powerPort;
        connect secondarySubstation3.lowSide to residentialConsumer2.powerPort;
        connect secondarySubstation3.lowSide to residentialConsumer3.powerPort;
        connect secondarySubstation3.lowSide to residentialConsumer4.powerPort;
        
        // Data connections to control center
        connect industrialConsumer1.smartMeter.dataPort to controlCenter.dataPort;
        connect industrialConsumer2.smartMeter.dataPort to controlCenter.dataPort;
        connect commercialConsumer1.smartMeter.dataPort to controlCenter.dataPort;
        connect commercialConsumer2.smartMeter.dataPort to controlCenter.dataPort;
        connect commercialConsumer3.smartMeter.dataPort to controlCenter.dataPort;
        connect residentialConsumer1.smartMeter.dataPort to controlCenter.dataPort;
        connect residentialConsumer2.smartMeter.dataPort to controlCenter.dataPort;
        connect residentialConsumer3.smartMeter.dataPort to controlCenter.dataPort;
        connect residentialConsumer4.smartMeter.dataPort to controlCenter.dataPort;
        
        connect batteryStorage1.dataPort to controlCenter.dataPort;
        connect batteryStorage2.dataPort to controlCenter.dataPort;
        
        // Control commands from control center
        connect controlCenter.dataPort.commands to industrialConsumer1.smartMeter.dataPort;
        connect controlCenter.dataPort.commands to industrialConsumer2.smartMeter.dataPort;
        connect controlCenter.dataPort.commands to commercialConsumer1.smartMeter.dataPort;
        connect controlCenter.dataPort.commands to commercialConsumer2.smartMeter.dataPort;
        connect controlCenter.dataPort.commands to commercialConsumer3.smartMeter.dataPort;
        connect controlCenter.dataPort.commands to residentialConsumer1.smartMeter.dataPort;
        connect controlCenter.dataPort.commands to residentialConsumer2.smartMeter.dataPort;
        connect controlCenter.dataPort.commands to residentialConsumer3.smartMeter.dataPort;
        connect controlCenter.dataPort.commands to residentialConsumer4.smartMeter.dataPort;
    }
    
    // ===== Requirements =====
    
    requirement def PowerGenerationRequirement {
        subject grid : SmartGridSystem;
        require {
            grid.gasPlant.currentOutput >= 2000[kW];
            grid.solarFarm1.currentOutput + grid.solarFarm2.currentOutput <= 10000[kW];
            grid.windTurbine1.currentOutput + grid.windTurbine2.currentOutput + grid.windTurbine3.currentOutput <= 9000[kW];
        }
    }
    
    requirement def StorageManagementRequirement {
        subject storage : BatteryStorage;
        require {
            storage.chargeLevel >= 0[%] and storage.chargeLevel <= 100[%];
            storage.maxChargeRate == 2000[kW];
            storage.maxDischargeRate == 2000[kW];
        }
    }
    
    requirement def GridStabilityRequirement {
        subject control : GridControlCenter;
        require {
            control.gridState == GridHealthState::stable
                when control.totalSupply >= control.totalDemand;
            control.gridState == GridHealthState::overloaded
                when control.totalDemand > control.totalSupply;
            control.gridState == GridHealthState::underloaded
                when control.totalSupply > control.totalDemand;
        }
    }
    
    requirement def LoadSheddingRequirement {
        subject grid : SmartGridSystem;
        require {
            grid.residentialConsumer1.isShed == true
                when grid.controlCenter.gridState == GridHealthState::overloaded;
            grid.residentialConsumer2.isShed == true
                when grid.controlCenter.gridState == GridHealthState::critical;
            grid.industrialConsumer1.isShed == false;
            grid.industrialConsumer2.isShed == false;
        }
    }
    
    requirement def RenewablePriorityRequirement {
        subject control : GridControlCenter;
        require {
            control.optimizeGeneration.renewablePriority == true
                when control.gridState == GridHealthState::stable;
        }
    }
    
    requirement def SmartMeterCommunicationRequirement {
        subject meter : SmartMeter;
        require {
            meter.demand >= 0[kW];
            meter.consumerId != "";
        }
    }
    
    requirement def TransmissionCapacityRequirement {
        subject line : TransmissionLine;
        require {
            line.currentLoad <= line.capacity;
            line.voltage == 230[kV];
        }
    }
    
    requirement def SubstationStepDownRequirement {
        subject primary : PrimarySubstation;
        subject secondary : SecondarySubstation;
        require {
            primary.inputVoltage == 230[kV];
            primary.outputVoltage == 69[kV];
            secondary.inputVoltage == 69[kV];
            secondary.outputVoltage == 12[kV];
        }
    }
    
    // ===== Requirement Satisfaction =====
    
    satisfaction satisfyPowerGen : PowerGenerationRequirement {
        subject grid : SmartGridSystem;
    }
    
    satisfaction satisfyStorage : StorageManagementRequirement {
        subject storage : BatteryStorage;
    }
    
    satisfaction satisfyStability : GridStabilityRequirement {
        subject control : GridControlCenter;
    }
    
    satisfaction satisfyLoadShedding : LoadSheddingRequirement {
        subject grid : SmartGridSystem;
    }
    
    satisfaction satisfyRenewablePriority : RenewablePriorityRequirement {
        subject control : GridControlCenter;
    }
    
    satisfaction satisfySmartMeter : SmartMeterCommunicationRequirement {
        subject meter : SmartMeter;
    }
    
    satisfaction satisfyTransmission : TransmissionCapacityRequirement {
        subject line : TransmissionLine;
    }
    
    satisfaction satisfySubstation : SubstationStepDownRequirement {
        subject primary : PrimarySubstation;
        subject secondary : SecondarySubstation;
    }
}
