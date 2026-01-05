package SurgicalDrapeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    
    doc /* 
     * This model describes a surgical drape system designed to establish and maintain
     * a sterile barrier field during surgical procedures. The primary function is to
     * isolate the surgical site from environmental contaminants while providing controlled
     * access for surgical instruments and procedures.
     */
    
    // Value types and enumerations
    enum def SterilityState {
        sterile;
        compromised;
        contaminated;
    }
    
    enum def DrapeMaterial {
        smsNonwoven;
        polyethyleneFilm;
        reusableTextile;
    }
    
    enum def FluidResistanceClass {
        level1;
        level2;
        level3;
        level4;
    }
    
    attribute def BarrierEfficiency :> Real;
    attribute def AdhesiveStrength :> Real;
    
    // Item definitions
    item def Microorganism {
        attribute size : LengthValue;
        attribute concentration : Real;
    }
    
    item def BodyFluid {
        attribute volume : VolumeValue;
        attribute flowRate : VolumeValue;
    }
    
    item def Patient {
        attribute bodyTemperature : TemperatureValue;
        port surgicalSite;
        port skinSurface;
    }
    
    item def SurgicalInstrument {
        attribute sterilityState : SterilityState;
        attribute mass : MassValue;
    }
    
    // Port definitions
    port def SterileBarrierPort {
        in item contaminants : Microorganism[*];
        out attribute barrierIntegrity : BarrierEfficiency;
    }
    
    port def FluidManagementPort {
        in item fluids : BodyFluid[*];
        out attribute absorptionCapacity : VolumeValue;
    }
    
    port def InstrumentAccessPort {
        inout item instruments : SurgicalInstrument[*];
        attribute accessDiameter : LengthValue;
    }
    
    // Part definitions
    part def BarrierLayer {
        attribute material : DrapeMaterial;
        attribute thickness : LengthValue;
        attribute porosity : Real;
        attribute microbialFiltrationEfficiency : BarrierEfficiency;
        
        port barrierInterface : SterileBarrierPort;
        
        assert constraint microbialBarrier {
            microbialFiltrationEfficiency >= 95.0
        }
    }
    
    part def AbsorbentLayer {
        attribute absorptionCapacity : VolumeValue;
        attribute saturationLevel : VolumeValue;
        attribute wicking : Real;
        
        port fluidIntake : FluidManagementPort;
        
        assert constraint capacityLimit {
            saturationLevel <= absorptionCapacity
        }
    }
    
    part def AdhesiveStrip {
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute peelStrength : ForceValue;
        attribute tackiness : AdhesiveStrength;
        
        assert constraint minimumAdhesion {
            peelStrength >= 5.0 [N]
        }
    }
    
    part def Fenestration {
        attribute diameter : LengthValue;
        attribute centerX : LengthValue;
        attribute centerY : LengthValue;
        attribute reinforced : Boolean;
        
        port accessOpening : InstrumentAccessPort;
    }
    
    part def ReinforcementZone {
        attribute area : AreaValue;
        attribute additionalThickness : LengthValue;
        attribute fluidResistance : FluidResistanceClass;
    }
    
    part def SurgicalDrape {
        attribute overallLength : LengthValue;
        attribute overallWidth : LengthValue;
        attribute totalMass : MassValue;
        attribute sterilityState : SterilityState;
        attribute fluidResistanceRating : FluidResistanceClass;
        
        part barrierLayer : BarrierLayer {
            attribute :>> material = DrapeMaterial::smsNonwoven;
            attribute :>> thickness = 0.08 [mm];
            attribute :>> microbialFiltrationEfficiency = 98.5;
        }
        
        part absorbentLayer : AbsorbentLayer {
            attribute :>> absorptionCapacity = 500.0 [mL];
            attribute :>> saturationLevel = 0.0 [mL];
            attribute :>> wicking = 0.85;
        }
        
        part adhesiveStrips : AdhesiveStrip[4] {
            attribute :>> length = 200.0 [mm];
            attribute :>> width = 25.0 [mm];
            attribute :>> peelStrength = 8.0 [N];
        }
        
        part fenestration : Fenestration[0..1] {
            attribute :>> diameter = 100.0 [mm];
            attribute :>> reinforced = true;
        }
        
        part reinforcementZones : ReinforcementZone[2] {
            attribute :>> area = 0.04 [m^2];
            attribute :>> additionalThickness = 0.05 [mm];
            attribute :>> fluidResistance = FluidResistanceClass::level4;
        }
        
        port environmentBarrier : SterileBarrierPort;
        port fluidManagement : FluidManagementPort;
        port surgicalAccess : InstrumentAccessPort[*];
        port patientContact;
        
        connection barrierConnection connect barrierLayer.barrierInterface to environmentBarrier;
        connection fluidConnection connect absorbentLayer.fluidIntake to fluidManagement;
        connection accessConnection connect fenestration.accessOpening to surgicalAccess;
        
        assert constraint totalMassCalculation {
            totalMass == barrierLayer.thickness * overallLength * overallWidth * 0.05 [kg/m^3] +
                         absorbentLayer.absorptionCapacity * 0.001 [kg/mL] +
                         sum(adhesiveStrips.length) * 0.002 [kg/m]
        }
    }
    
    part def SterileField {
        attribute establishedTime : TimeValue;
        attribute maintenanceDuration : DurationValue;
        attribute integrityStatus : SterilityState;
        attribute protectedArea : AreaValue;
        
        part drapes : SurgicalDrape[1..*];
        
        port fieldBoundary : SterileBarrierPort;
        port protectedZone;
        
        assert constraint fieldIntegrity {
            integrityStatus == SterilityState::sterile
        }
    }
    
    part def OperatingEnvironment {
        attribute ambientTemperature : TemperatureValue;
        attribute relativeHumidity : Real;
        attribute airPressure : PressureValue;
        attribute particleCount : Real;
        
        part sterileField : SterileField;
        part patient : Patient;
        part instruments : SurgicalInstrument[*];
        
        connection patientDraping connect sterileField.protectedZone to patient.surgicalSite;
        connection skinAdhesion connect sterileField.drapes.patientContact to patient.skinSurface;
    }
    
    // Action definitions
    action def InspectPackaging {
        in drape : SurgicalDrape;
        out integrityConfirmed : Boolean;
    }
    
    action def OpenSterilePackage {
        in drape : SurgicalDrape;
        out exposedDrape : SurgicalDrape;
    }
    
    action def UnfoldDrape {
        in drape : SurgicalDrape;
        out unfoldedDrape : SurgicalDrape;
    }
    
    action def PositionOverSite {
        in drape : SurgicalDrape;
        in patient : Patient;
        out positionedDrape : SurgicalDrape;
    }
    
    action def SecureToPatient {
        in drape : SurgicalDrape;
        out securedDrape : SurgicalDrape;
    }
    
    action def MonitorBarrierIntegrity {
        in field : SterileField;
        out integrityStatus : SterilityState;
    }
    
    action def ManageFluidAccumulation {
        in drape : SurgicalDrape;
        in fluids : BodyFluid;
        out absorptionStatus : Real;
    }
    
    action def RemoveDrape {
        in drape : SurgicalDrape;
        out disposedDrape : SurgicalDrape;
    }
    
    action def EstablishAndMaintainSterileField {
        first start;
        then action inspect : InspectPackaging;
        then action open : OpenSterilePackage {
            in drape = inspect.drape;
        }
        then action unfold : UnfoldDrape {
            in drape = open.exposedDrape;
        }
        then action position : PositionOverSite {
            in drape = unfold.unfoldedDrape;
        }
        then action secure : SecureToPatient {
            in drape = position.positionedDrape;
        }
        then merge maintenanceLoop;
        then action monitor : MonitorBarrierIntegrity;
        then action manageFluid : ManageFluidAccumulation;
        then decide;
            if monitor.integrityStatus == SterilityState::sterile and 
               manageFluid.absorptionStatus < 0.9 then continueMonitoring;
            if monitor.integrityStatus == SterilityState::compromised then alertTeam;
            if monitor.integrityStatus == SterilityState::contaminated or
               manageFluid.absorptionStatus >= 0.9 then replaceDrape;
        action continueMonitoring;
        then maintenanceLoop;
        action alertTeam;
        then maintenanceLoop;
        action replaceDrape;
        then action remove : RemoveDrape;
        then done;
    }
    
    // State machine definition
    state def DrapeLifecycle {
        entry; then packaged;
        
        state packaged;
        
        transition packageOpened
            first packaged
            accept at openingTime
            do action openAction : OpenSterilePackage
            then unfolded;
        
        state unfolded;
        
        transition drapePositioned
            first unfolded
            accept at positioningTime
            do action positionAction : PositionOverSite
            then positioned;
        
        state positioned;
        
        transition drapeSecured
            first positioned
            accept at securingTime
            do action secureAction : SecureToPatient
            then inUse;
        
        state inUse;
        
        transition breachDetected
            first inUse
            if barrierLayer.microbialFiltrationEfficiency < 95.0
            then compromised;
        
        state compromised;
        
        transition contaminationConfirmed
            first compromised
            accept at contaminationTime
            then contaminated;
        
        state contaminated;
        
        transition drapeRemoved
            first contaminated
            do action removeAction : RemoveDrape
            then disposed;
        
        transition normalRemoval
            first inUse
            accept at procedureEnd
            do action removeAction : RemoveDrape
            then disposed;
        
        state disposed;
    }
    
    // Requirements
    requirement def SterilityBarrierRequirement {
        doc /* The surgical drape shall provide a sterile barrier that prevents
             * microbial penetration with a filtration efficiency of at least 95%. */
        subject drape : SurgicalDrape;
        require constraint {
            drape.barrierLayer.microbialFiltrationEfficiency >= 95.0
        }
    }
    
    requirement def FluidResistanceRequirement {
        doc /* The surgical drape shall resist fluid strike-through and absorb
             * at least 500 mL of body fluids during typical procedures. */
        subject drape : SurgicalDrape;
        require constraint {
            drape.absorbentLayer.absorptionCapacity >= 500.0 [mL] and
            drape.fluidResistanceRating == FluidResistanceClass::level4
        }
    }
    
    requirement def AdhesionRequirement {
        doc /* The surgical drape adhesive strips shall maintain secure attachment
             * to patient skin with minimum peel strength of 5 N per strip. */
        subject drape : SurgicalDrape;
        require constraint {
            forall (strip in drape.adhesiveStrips) 
                strip.peelStrength >= 5.0 [N]
        }
    }
    
    requirement def CoverageRequirement {
        doc /* The surgical drape shall provide adequate coverage area to establish
             * a sterile field of at least 1.5 m² around the surgical site. */
        subject drape : SurgicalDrape;
        require constraint {
            drape.overallLength * drape.overallWidth >= 1.5 [m^2]
        }
    }
    
    requirement def AccessRequirement {
        doc /* The surgical drape fenestration shall provide controlled access
             * to the surgical site with a minimum diameter of 100 mm. */
        subject drape : SurgicalDrape;
        require constraint {
            exists (f in drape.fenestration) f.diameter >= 100.0 [mm]
        }
    }
    
    requirement <'REQ-SD-PRIMARY'> primaryFunctionRequirement {
        doc /* The surgical drape system shall establish and maintain a sterile
             * barrier field that isolates the surgical site from environmental
             * contaminants while providing controlled access for surgical procedures. */
        subject system : OperatingEnvironment;
        
        assume constraint environmentalConditions {
            system.ambientTemperature >= 18.0 [Celsius] and
            system.ambientTemperature <= 24.0 [Celsius] and
            system.relativeHumidity >= 20.0 and
            system.relativeHumidity <= 60.0
        }
        
        require sterilityReq : SterilityBarrierRequirement {
            subject drape :>> system.sterileField.drapes;
        }
        
        require fluidReq : FluidResistanceRequirement {
            subject drape :>> system.sterileField.drapes;
        }
        
        require adhesionReq : AdhesionRequirement {
            subject drape :>> system.sterileField.drapes;
        }
        
        require coverageReq : CoverageRequirement {
            subject drape :>> system.sterileField.drapes;
        }
        
        require accessReq : AccessRequirement {
            subject drape :>> system.sterileField.drapes;
        }
    }
    
    // System instantiation
    part surgicalProcedureSetup : OperatingEnvironment {
        attribute :>> ambientTemperature = 21.0 [Celsius];
        attribute :>> relativeHumidity = 45.0;
        attribute :>> airPressure = 101.5 [kPa];
        attribute :>> particleCount = 100.0;
        
        part :>> sterileField {
            attribute :>> establishedTime = 0.0 [s];
            attribute :>> maintenanceDuration = 14400.0 [s];
            attribute :>> integrityStatus = SterilityState::sterile;
            attribute :>> protectedArea = 2.0 [m^2];
            
            part :>> drapes : SurgicalDrape[2] {
                attribute :>> overallLength = 1.8 [m];
                attribute :>> overallWidth = 1.2 [m];
                attribute :>> totalMass = 0.35 [kg];
                attribute :>> sterilityState = SterilityState::sterile;
                attribute :>> fluidResistanceRating = FluidResistanceClass::level4;
            }
        }
        
        part :>> patient {
            attribute :>> bodyTemperature = 37.0 [Celsius];
        }
        
        perform action operationalSequence : EstablishAndMaintainSterileField;
    }
    
    satisfy primaryFunctionRequirement by surgicalProcedureSetup;
}
