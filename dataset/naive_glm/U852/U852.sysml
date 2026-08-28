package ElectrochemicalSystem {
    import ScalarValues::Real;
    import ScalarValues::String;
    import ISQ::ElectricPotential;
    import ISQ::ElectricCurrent;
    import ISQ::Area;
    import ISQ::Volume;
    
    // Item and Value Types
    item def Electrolyte {
        attribute pH : Real;
        attribute conductivity : Real; // S/m
    }
    
    attribute def ChemicalSpecies {
        attribute name : String;
        attribute oxidationPotential : ElectricPotential;
        attribute reductionPotential : ElectricPotential;
    }
    
    // Port Definitions
    port def ElectricalPort {
        attribute potential : ElectricPotential;
        attribute current : ElectricCurrent;
    }
    
    port def ChemicalInterfacePort {
        // Interaction between electrode and electrolyte
    }
    
    // Part Definitions
    part def Electrode {
        attribute material : String;
        attribute surfaceArea : Area;
        port electricalConnection : ElectricalPort;
        port chemicalInterface : ChemicalInterfacePort;
    }
    
    part def WorkingElectrode :> Electrode {
        attribute catalyticProperty : String;
    }
    
    part def CounterElectrode :> Electrode {
    }
    
    part def ReferenceElectrode :> Electrode {
        attribute stablePotential : ElectricPotential;
    }
    
    part def ElectrolyteReservoir {
        port electrolytePort : ChemicalInterfacePort;
        part electrolyte : Electrolyte;
        attribute volume : Volume;
    }
    
    part def Potentiostat {
        port workingPort : ElectricalPort;
        port counterPort : ElectricalPort;
        port referencePort : ElectricalPort;
        
        attribute appliedVoltage : ElectricPotential;
        attribute measuredCurrent : ElectricCurrent;
        
        state PotentiostatStates {
            state idle;
            state oxidizing;
            state reducing;
            
            transition initial to idle;
            transition idle to oxidizing when (self.appliedVoltage > 0 [V]);
            transition oxidizing to idle when (self.appliedVoltage == 0 [V]);
            transition idle to reducing when (self.appliedVoltage < 0 [V]);
            transition reducing to idle when (self.appliedVoltage == 0 [V]);
            transition oxidizing to reducing when (self.appliedVoltage < 0 [V]);
            transition reducing to oxidizing when (self.appliedVoltage > 0 [V]);
        }
        
        action def PerformRedoxCycle {
            doc /* Performs a full redox cycle, switching between oxidizing and reducing chemical species in the electrolyte. */
        }
    }
    
    part def ElectrochemicalCellSystem {
        part potentiostat : Potentiostat;
        part workingElectrode : WorkingElectrode;
        part counterElectrode : CounterElectrode;
        part referenceElectrode : ReferenceElectrode;
        part reservoir : ElectrolyteReservoir;
        
        connect potentiostat.workingPort to workingElectrode.electricalConnection;
        connect potentiostat.counterPort to counterElectrode.electricalConnection;
        connect potentiostat.referencePort to referenceElectrode.electricalConnection;
        
        connect workingElectrode.chemicalInterface to reservoir.electrolytePort;
        connect counterElectrode.chemicalInterface to reservoir.electrolytePort;
        connect referenceElectrode.chemicalInterface to reservoir.electrolytePort;
    }
    
    // Requirements
    requirement def PotentialControlRequirement {
        doc /* The electrode's potential must be precisely controlled */
        subject electrodePotential : ElectricPotential;
        attribute maxControlPrecision : ElectricPotential = 0.001 [V];
        constraint { electrodePotential <= maxControlPrecision }
    }
    
    requirement def CurrentMeasurementRequirement {
        doc /* The resulting current must be measured with high resolution */
        subject measuredCurrent : ElectricCurrent;
        attribute maxMeasurementResolution : ElectricCurrent = 0.000001 [A];
        constraint { measuredCurrent <= maxMeasurementResolution }
    }
    
    requirement def StabilityRequirement {
        doc /* The potential remains stable over time */
        subject potentialDrift : ElectricPotential;
        attribute maxDriftPerHour : ElectricPotential = 0.0001 [V];
        constraint { potentialDrift <= maxDriftPerHour }
    }
}
