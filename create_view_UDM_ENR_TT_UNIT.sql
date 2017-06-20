IF EXISTS (SELECT * FROM sysobjects WHERE type = 'V' AND name = 'UDM_ENR_TT_UNIT')
	drop view dbo.UDM_ENR_TT_UNIT
GO

create view dbo.UDM_ENR_TT_UNIT as
/*
   UDM_ENR_TT_UNIT
   The purpose of this view is to show all learners enrolled in units

   Modification History
   ====================
   13/10/2016 - Frances W - created script
   2/12/2016  - Frances W - updated to meet naming conventions
   8/12/2016  - Frances W - continue update to meet naming conventions and added extended property labels
   01/02/2017 - Trent M - added Learner_Group, Learner_Group_Description ,Delivery_Location & Offering_Description
   07/03/2017 - Frances W - Added fields for BI: Is_Accredited, Is_Short_Course, Unit_Hours, Scope_Approved, Offering_Total_Places
   08/03/2017 - Frances W - Added Progress_Code to be used as FK to DIM_PROGRESS, mode of attendance field, Fund_Code as FK to DIM_FUNDING, Campus_Code as FK to DIM_CAMPUS
   03/04/2017 - Frances W - Change Current_year calc
   30/05/2017 - Trent M - added completion year and updated current year filter
*/
select
	cy.Completion_Year
	,Delivery_Team=uio.OFFERING_ORGANISATION + '-' + ouTeam.FES_FULL_NAME
	,Campus=lo.FES_LONG_DESCRIPTION
	,Delivery_Location = uio.Delivery_Location
	,PERSON_CODE=pu.PERSON_CODE													--Learner ID
	,Learner_Name=COALESCE(p.FORENAME + ' ', '') + COALESCE(iif(patindex('% %',p.MIDDLE_NAMES)=0,p.MIDDLE_NAMES,substring(p.MIDDLE_NAMES,1,patindex('% %',p.MIDDLE_NAMES)-1)) + ' ','') + isnull(p.SURNAME,'')									--Learner Name (first given name + space + surname)
	,COURSE_CODE=pu.UNIT_INSTANCE_CODE											--Product Code (add hook to Product Details)
	,Product_Name=ui.FES_LONG_DESCRIPTION
	,Cal_Occ_Code=pu.CALOCC_CODE
	,Offering_Description = uio.FES_USER_1
	,Learner_Group = t.tutorgroup_name
	,Learner_Group_Description = t.tutorgroup_user_2											        --Cal Occ Code
	,Enrolment_Date_D=pu.CREATED_DATE
--	,Unit_Progress_code = pu.PROGRESS_CODE
	,Progress=pu.PROGRESS_CODE + ' - ' + pc.FES_LONG_DESCRIPTION			--Enrolment Progress ( Code + dash + Description)
	,Progress_Code=pu.PROGRESS_CODE											--to be used as Foreign Key to DIM_PROGRESS table
	,Progress_Date_d=pu.PROGRESS_DATE									    --Progress Date
	,Start_Date_d=COALESCE(pus.start_date,uio.fes_start_date)			    --Start Date (Special Details Date, otherwise Offering Start Date)
	,End_Date_d=COALESCE(pus.end_date,uio.fes_end_date)					    --End Date (Special Details Date, otherwise Offering Start Date)
	,Product_Status=ui.fes_Status
	,Fund_Code=pu.NZ_FUNDING
	,Fund_Source=pu.NZ_FUNDING + ' - ' + vFunding.FES_LONG_DESCRIPTION		--Funding Source  (Code + dash + Description)
	,COURSE_ID=uio.UIO_ID													--Offering ID (add hook to Offering Details)
	,ENROLMENT_ID=pu.ID														--Enrolment ID (add hook to Enrolment Details)
	,outcome=a.grade + ' - ' + gs.DESCRIPTION								--Grade + dash + Grade Description (GRADING_SCHEME_GRADES)
	,date_awarded=a.Date_Awarded
	,Division=ou.FES_FULL_NAME
	--,Current_Year=case when COALESCE(pus.start_date,uio.fes_start_date) < CONVERT(date,'2018-01-01 00:00:00.000',121) and COALESCE(pus.end_date,uio.fes_end_date) > CONVERT(date,'2016-12-31 00:00:00.000',121) then 'Y' else 'N' end
	,Current_Year=case when cy.Completion_Year=year(getdate()) then 'Y' else 'N' end
	-- the following fields have been added as they may be useful for business intelligence
	,Is_Accredited=ui.IS_ACCREDITED
	,Is_Short_Course=ui.IS_SHORT_COURSE
	,Unit_Hours=ui.MAXIMUM_HOURS
	,Scope_Approved=ui.SCOPE_APPROVED
	,Offering_Total_Places=uio.TOTAL_PLACES
	,Mode_Of_Attendance=vMOA.FES_LONG_DESCRIPTION
	,Campus_Code=uio.SLOC_LOCATION_CODE
from	
	people_units pu																-- get course enrolments
	left join people p on pu.PERSON_CODE = p.PERSON_CODE						-- get learner details						
	left join unit_instances ui on ui.FES_UNIT_INSTANCE_CODE=pu.UNIT_INSTANCE_CODE -- get course details
	left join unit_instance_occurrences uio on uio.uio_id = pu.uio_id			-- Join to Offerings
	left join progress_codes pc ON pu.PROGRESS_CODE = pc.TYPE_NAME and pc.STUDENT_STATUS = 'R'
	left join people_units_special pus on pus.PEOPLE_UNITS_ID=pu.ID and pu.SPECIAL_DETAILS='Y' -- Join to Special Details if flagged to Y
	left join VERIFIERS vFunding on pu.NZ_FUNDING = vFunding.LOW_VALUE and vFunding.rv_domain = 'FUNDING'
	left join ATTAINMENTS a on pu.ID = a.PEOPLE_UNITS_ID						-- get unit outcomes  -- migrated data does not have PEOPLE_UNITS_ID to link on TM 12-05-2017.
	left join GRADING_SCHEME_GRADES gs on a.GRADE = gs.GRADE and gs.grading_scheme_id = ui.grading_scheme_id
	left join configurable_statuses cs on a.CONFIGURABLE_STATUS_ID = cs.ID
	left join ORG_UNIT_LINKS oul on oul.SECONDARY_ORGANISATION = uio.OFFERING_ORGANISATION
	left join ORGANISATION_UNITS ou on oul.PRIMARY_ORGANISATION = ou.ORGANISATION_CODE
	left join  ORGANISATION_UNITS ouTeam on uio.OFFERING_ORGANISATION = ouTeam.ORGANISATION_CODE
	left join LOCATIONS lo on lo.LOCATION_CODE = uio.SLOC_LOCATION_CODE
	left join dbo.EBS_PEOPLEUNIT_TUTORGROUPS T on /*pu.UIO_ID = t.uio_id and*/ pu.PERSON_CODE = t.person_code and pu.id = t.people_units_id
	left join verifiers vMOA on uio.fes_user_8 = vMOA.LOW_VALUE and vMOA.rv_domain = 'ATTENDANCE_MODE' and vMOA.fes_active = 'Y'
	left join TasTAFE.Completion_Year cy on cy.Enrolment_ID=pu.ID
where
	p.FES_STAFF_CODE is null													-- get only learners
	and ui.UI_LEVEL = 'UNIT'													-- get only units
--	and a.grade is not null
GO
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT', @value=N'Unit Enrolments' , @name=N'MS_Description', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW'
go
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'PERSON_CODE', @value=N'Learner ID', @name=N'MS_Description', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'COURSE_CODE', @value=N'Product Code', @name=N'MS_Description', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'COURSE_ID', @value=N'Offering ID', @name=N'MS_Description', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
go

-- ADD LABELS USING EXTENDED PROPERTIES
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Course_Code', @value=N'Product Code', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Product_Status', @value=N'Product Status', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Cal_Occ_Code', @value=N'Cal Occ Code', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Campus', @value=N'Campus', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'current_year', @value=N'Current Year', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Delivery_Team', @value=N'Delivery Team', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Division', @value=N'Division', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Enrolment_Date_D', @value=N'Enrolment Date', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'ENROLMENT_ID', @value=N'Enrolment Id', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Fund_Code', @value=N'Fund Code', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Fund_Source', @value=N'Fund Source', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Learner_Name', @value=N'Learner Name', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'PERSON_CODE', @value=N'Learner ID', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'COURSE_ID', @value=N'Offering ID', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'date_awarded', @value=N'Date Awarded', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'product_name', @value=N'Product Name', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'End_Date_d', @value=N'End Date', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'outcome', @value=N'Outcome', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Progress', @value=N'Progress', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Progress_Code', @value=N'Progress Code', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Progress_Date_d', @value=N'Progress Date', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Start_Date_d', @value=N'Start Date', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Offering_Description', @value=N'Offering Description', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Learner_Group', @value=N'Learner Group', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Learner_Group_Description', @value=N'Learner Group Description', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Is_Accredited', @value=N'Is Accredited', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Is_Short_Course', @value=N'Is Short Course', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Unit_Hours', @value=N'Unit Hours', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Scope_Approved', @value=N'Scope Approved', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Offering_Total_Places', @value=N'Offering Total Places', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Mode_Of_Attendance', @value=N'Mode Of Attendance', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Campus_Code', @value=N'Campus Code', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
EXEC sys.sp_addextendedproperty @level1name=N'UDM_ENR_TT_UNIT',@level2name=N'Completion_Year', @value=N'Completion Year', @name=N'Label', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW', @level2type=N'COLUMN'
go

--select * from PEOPLE_UNITS 

--select UNIT_INSTANCE_CODE , CALOCC_CTYPE from PEOPLE_UNITS 
