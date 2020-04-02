with protocols as (
    select pcl.protocol_no,
    pcl.protocol_id,
    pcl.treatment_type_desc,
    pcl.investigator_initiated,
    pcl.created_date,
    pcl.summary4_report_desc,
    pcl.investigational_drug,
    pcl.precision_trial,
    pcl.status,
    case when cto.protocol_no is null then 0 else 1 end as cto,
    case when cto_reg.protocol_no is null then 0 else 1 end as cto_reg,
    case when excl.protocol_no is null then 0 else 1 end as exclude_please,
    case when incl.protocol_no is null then 0 else 1 end as include_please,
    case when cog.protocol_no is null then 0 else 1 end as cog
    from sv_protocol pcl
    left join (
    select *
    from sv_pcl_mgmt_mgmtgroup
    where mgmt_group_description = 'Accrual Exclusion'
    ) excl on excl.protocol_no = pcl.protocol_no
    left join (
    select *
    from sv_pcl_mgmt_mgmtgroup
    where mgmt_group_description = 'Accrual Inclusion'
    ) incl on incl.protocol_no = pcl.protocol_no
    left join (
    select *
    from sv_pcl_mgmt_mgmtgroup
    where mgmt_group_description = 'Clinical Trials Office'
    ) cto on cto.protocol_no = pcl.protocol_no
    left join (
    select *
    from sv_pcl_mgmt_mgmtgroup
    where mgmt_group_description = 'CTO Regulatory'
  ) cto_reg on cto_reg.protocol_no = pcl.protocol_no
    left join (
    select *
    from sv_pcl_mgmt_mgmtgroup
    where mgmt_group_description = 'COG'
    ) cog on cog.protocol_no = pcl.protocol_no
    order by exclude_please desc, pcl.protocol_no
),

sites as (
select protocol_no,
count(*) count
from (
select protocol_no,
institution_name,
study_sites
from sv_pcl_institution
where institution_name != 'Hawaii Cancer Consortium')
group by protocol_no
order by protocol_no
),

sub_sites as (
select protocol_no,
count(*) count
from (
select protocol_no,
study_site_name,
status
from rv_pcl_study_site
where institution_name != 'Hawaii Cancer Consortium'
and study_site_name != 'Cancer Center of Hawaii')
group by protocol_no
order by protocol_no
),

sub_investigators as (
select protocol_no,
count(*) count
from (
select protocol_no,
staff_name,
role_desc
from sv_pcl_staff_role
where role_desc = 'Sub-Investigator'
and subject_mrn is null
and stop_date is not null)
group by protocol_no
order by protocol_no
),

research_nurses as (
select protocol_no,
count(*) count
from (
select protocol_no,
staff_name,
role_desc
from sv_pcl_staff_role
where role_desc = 'Clinical Research Nurse'
and organization_id != 2
and subject_mrn is null
and stop_date is not null)
group by protocol_no
order by protocol_no
),

irb as (
select protocol_no,
meeting_date,
irb_committee
from (
select lr.protocol_no,
lr.meeting_date,
irb.irb_committee
from (
select protocol_no,
max(meeting_date) meeting_date
from (
select protocol_no,
meeting_date
from sv_irb_review
where institution_name = 'Hawaii Cancer Consortium')
group by protocol_no) lr
left join sv_irb_review irb on irb.protocol_no = lr.protocol_no and lr.meeting_date = irb.meeting_date)
group by protocol_no, meeting_date, irb_committee
order by protocol_no, meeting_date desc
),

sponsor as (
select protocol_no,
sponsor_type_description
from sv_pcl_sponsor
where principal_sponsor = 'Y'
),

last_accrual as (
select protocol_no,
max(on_studydate) last_enrollment
from sv_pcl_subject
group by protocol_no
order by protocol_no
),

pcl_status as (
select cs.protocol_no,
ps.status,
cs.current_status_date as status_date
from(
select protocol_no,
max(status_date) as current_status_date
from sv_pcl_status
where status != 'NEW'
group by protocol_no
) cs
left join sv_pcl_status ps on ps.protocol_no = cs.protocol_no and ps.status_date = cs.current_status_date
order by protocol_no
),

notes as (
select protocol_no,
sum(has_fda) as has_fda,
sum(has_dtl) as has_dtl
from (
select protocol_no,
case when instr(lower(note),'fda') != 0 then 1 else 0 end as has_fda,
case when instr(lower(note),'dtl') != 0 then 1 else 0 end as has_dtl
from sv_pcl_notes)
group by protocol_no
)

select pcl.protocol_no,
--pcl.status,
--ps.status_date,
--la.last_enrollment,
decode(pcl.investigator_initiated, 'Y',1,0) iit,
decode(pcl.summary4_report_desc, 'Interventional', 1, 0.25) dt4,
decode(pcl.investigational_drug, 'Y',1,0) drug,
decode(pcl.precision_trial, 'Y',1,0) precision,
decode(s.count, null, 0, s.count) sites,
decode(ss.count, null, 0, ss.count) subsites,
si.count as sub_inv,
rn.count as rn,
case irb.irb_committee when 'UH IRB' then 1
                       when 'Western IRB (WIRB)' then 0.75
                       else 0.5 end as irb,
decode(sp.sponsor_type_description, 'National', .5, 1) sponsor,
decode(n.has_fda, 1, 1, 0) fda  /*,
case when n.has_dtl = 1 then 1*s.count else 0 end as dtl */
from protocols pcl
left join sites s on s.protocol_no = pcl.protocol_no
left join sub_sites ss on ss.protocol_no = pcl.protocol_no
left join sub_investigators si on si.protocol_no = pcl.protocol_no
left join research_nurses rn on rn.protocol_no = pcl.protocol_no
left join irb on irb.protocol_no = pcl.protocol_no
left join sponsor sp on sp.protocol_no = pcl.protocol_no
left join last_accrual la on la.protocol_no = pcl.protocol_no
left join pcl_status ps on ps.protocol_no = pcl.protocol_no and ps.status = pcl.status
left join notes n on n.protocol_no = pcl.protocol_no
where /* pcl.status not in ('NEW', 'IRB STUDY CLOSURE','SUSPENDED','ABANDONED','TERMINATED')
and */ (pcl.cto = 1 or pcl.cto_reg = 1 or summary4_report_desc = 'Interventional')
and pcl.cog = 0
order by /*case status when 'PRMC APPROVAL' then 1
                     when 'IRB INITIAL APPROVAL' then 2
                     when 'OPEN TO ACCRUAL' then 3
                     when 'CLOSED TO ACCRUAL' then 4
                     else 5 end, */
protocol_no
