-- ============================================================================
-- OPTIONAL — sample/test data, mirroring what's currently hardcoded in
-- index.html, so you can see the site working end-to-end before real alumni
-- data goes in. Run this AFTER schema.sql, in the SQL Editor.
--
-- DELETE THIS DATA before the real launch (see the DELETE statements at the
-- very bottom of this file — uncomment and run them when you're ready).
-- ============================================================================

-- Committee: one current term, 9 members
with term as (
  insert into public.committee_terms (label, start_year, end_year, is_current)
  values ('Founding term · 2024–2026', 2024, 2026, true)
  returning id
)
insert into public.committee (term_id, full_name, role, batch, linkedin, facebook, email, phone, sort_order)
select id, v.full_name, v.role, v.batch, v.linkedin, v.facebook, v.email, v.phone, v.sort_order
from term, (values
  ('Dr. M. Kabir', 'President', 2005, 'https://linkedin.com/in/example', '', 'kabir@example.com', '+8801XXXXXXXXX', 1),
  ('S. Chowdhury', 'Vice President', 2008, '', 'https://facebook.com/example', 'chowdhury@example.com', '+8801XXXXXXXXX', 2),
  ('A. Rahman', 'General Secretary', 2012, 'https://linkedin.com/in/example', '', 'rahman@example.com', '+8801XXXXXXXXX', 3),
  ('N. Sultana', 'Joint General Secretary', 2014, '', 'https://facebook.com/example', 'sultana@example.com', '+8801XXXXXXXXX', 4),
  ('F. Islam', 'Treasurer', 2013, 'https://linkedin.com/in/example', '', 'fislam@example.com', '+8801XXXXXXXXX', 5),
  ('T. Ahmed', 'Organizing Secretary', 2015, '', 'https://facebook.com/example', 'tahmed@example.com', '+8801XXXXXXXXX', 6),
  ('R. Karim', 'Publicity & Publications Sec.', 2016, 'https://linkedin.com/in/example', '', 'rkarim@example.com', '+8801XXXXXXXXX', 7),
  ('S. Akter', 'Secretary, Women''s Affairs', 2019, '', 'https://facebook.com/example', 'sakter@example.com', '+8801XXXXXXXXX', 8),
  ('I. Hossain', 'Secretary, Student Affairs', 2017, 'https://linkedin.com/in/example', '', 'ihossain@example.com', '+8801XXXXXXXXX', 9)
) as v(full_name, role, batch, linkedin, facebook, email, phone, sort_order);

-- Members (public-safe fields)
insert into public.members (full_name, location, email, linkedin, facebook, programme, passing_year, organization, designation, membership_type)
values
  ('Farhana Islam', 'Gopalganj, BD', 'farhana.i@example.com', '', '', 'B.Sc.', 2019, 'Square Pharmaceuticals', 'Process Engineer', 'General'),
  ('Tanvir Ahmed', 'Dhaka, BD', 'tanvir.a@example.com', 'https://linkedin.com/in/example', '', 'M.Sc.', 2015, 'ACI Limited', 'QA Manager', 'Life'),
  ('Nusrat Jahan', 'Chattogram, BD', 'nusrat.j@example.com', '', 'https://facebook.com/example', 'B.Sc.', 2021, 'BCSIR', 'Research Assistant', 'General'),
  ('Rezaul Karim', 'Khulna, BD', 'rezaul.k@example.com', 'https://linkedin.com/in/example', '', 'PhD', 2012, 'KUET', 'Assistant Professor', 'Life'),
  ('Shirin Akter', 'Dhaka, BD', 'shirin.a@example.com', '', '', 'B.Sc.', 2019, 'Beximco Pharmaceuticals', 'Formulation Chemist', 'General'),
  ('Imran Hossain', 'Toronto, CA', 'imran.h@example.com', 'https://linkedin.com/in/example', '', 'M.Sc.', 2017, 'Arup', 'Senior Environmental Consultant', 'Life'),
  ('Mahmuda Begum', 'Dhaka, BD', 'mahmuda.b@example.com', '', '', 'B.Sc.', 2023, 'Renata Limited', 'Executive, QA', 'General');

-- Matching private details (student IDs / mobiles) for the same 7, in order
insert into public.member_private_details (member_id, student_id, mobile_phone)
select m.id, v.student_id, v.mobile_phone
from public.members m
join (values
  ('farhana.i@example.com', '1501001', '+8801710000001'),
  ('tanvir.a@example.com', '1101014', '+8801710000002'),
  ('nusrat.j@example.com', '1701022', '+8801710000003'),
  ('rezaul.k@example.com', '0801005', '+8801710000004'),
  ('shirin.a@example.com', '1501033', '+8801710000005'),
  ('imran.h@example.com', '1301019', '+1XXXXXXXXXX'),
  ('mahmuda.b@example.com', '1901041', '+8801710000007')
) as v(email, student_id, mobile_phone) on v.email = m.email;

-- Events / news
insert into public.events (kind, title, description, event_date) values
  ('event', 'Annual Alumni Reunion 2026', 'A full-day gathering at the department premises with a campus tour, cultural programme, and an open networking session for all batches.', '2026-11-14'),
  ('news', 'Founding Committee Formed', 'The founding Executive Committee has been formed on the basis of batch representatives, in line with Article 12 of the Constitution.', '2026-11-02'),
  ('event', 'Career Talk: Careers in Process Industries', 'A panel of senior alumni working across the pharmaceutical and chemical process industries, followed by an open Q&A session for current students.', '2026-12-02'),
  ('news', 'Membership Drive Begins', 'General and Life membership registration is now open through the department office for all eligible graduates.', '2027-01-20');

-- Achievements
insert into public.achievements (alumni_name, batch, tag, description) values
  ('Nusrat Jahan', 2021, 'Higher Study', 'Selected for an M.Sc. in Chemical Engineering at the National University of Singapore.'),
  ('Imran Hossain', 2017, 'Career', 'Promoted to Senior Environmental Consultant at Arup, Toronto.'),
  ('Mahmuda Begum', 2023, 'Job', 'Joined Renata Limited as an Executive in Quality Assurance.'),
  ('Tanvir Ahmed', 2015, 'Career', 'Appointed QA Manager at ACI Limited after five years in formulation development.'),
  ('Rezaul Karim', 2012, 'Higher Study', 'Completed a PhD and joined KUET as Assistant Professor.'),
  ('Shirin Akter', 2019, 'Job', 'Hired as Formulation Chemist at Beximco Pharmaceuticals.'),
  ('Farhana Islam', 2019, 'Job', 'Joined Square Pharmaceuticals as Process Engineer in the manufacturing division.'),
  ('Sabbir Rahman', 2015, 'Career', 'Relocated to Dubai as an MBBR Systems Engineer for a regional water-treatment firm.');

-- Notices
insert into public.notices (title, description) values
  ('Membership Drive 2026', 'General and Life membership registration is now open through the department office.'),
  ('AGM Notice', 'The first Annual General Meeting will be announced here once the date is finalized.');

-- Partners
insert into public.partners (name, sort_order) values
  ('GSTU', 1), ('Dept. of ACCE', 2), ('Industry Partner', 3), ('Research Partner', 4);

-- A couple of sample pending submissions, for testing the approve flow
insert into public.pending_submissions (submission_type, full_name, passing_year, note) values
  ('new', 'Kamrul Hasan', 2020, 'New submission — job title changed'),
  ('new', 'Tania Sultana', 2018, 'Update — new location & email');

-- ----------------------------------------------------------------------------
-- Cleanup — uncomment and run when you're ready to go live with real data:
-- ----------------------------------------------------------------------------
-- delete from public.pending_submissions;
-- delete from public.member_private_details;
-- delete from public.members;
-- delete from public.achievements;
-- delete from public.events;
-- delete from public.notices;
-- delete from public.partners;
-- delete from public.committee;
-- delete from public.committee_terms;
