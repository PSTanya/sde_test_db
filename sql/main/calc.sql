--Создаю таблицу для результатов:
create table results
(id INT, 
response text);

select * from results;

--1. Ищу максимальное кол-во пассажиров в бронировании

insert into results
select 1, count(distinct passenger_id) max_num
from Tickets
group by book_ref
order by max_num desc
limit 1;

--2. Ищу кол-во бронирований с кол-вом людей> среднего кол-во в бронировании

insert into results
select 2, count( distinct book_ref) from
	(
	select book_ref, count(passenger_id) as num_passenger from tickets  --группироую брони с кол-вом пассажиров
	group by book_ref
	) a
where num_passenger > (                                  --отбираю по условию больше среднего
	select avg(num_in_booking) as avgnum from            --нахожу среднее кол-во пассажиров в одной брони
(
select 
book_ref,
count(passenger_id) over (partition by book_ref) as num_in_booking
from tickets) b);

--3.Вывести количество бронирований, у которых состав пассажиров повторялся два и более раза,
-- среди бронирований с максимальным количеством людей (п.1)?

	INSERT INTO results
SELECT 3, count(*)
FROM(
	SELECT book_ref, passenger_id, passenger_name, count(passenger_id) over (partition by book_ref) as num_in_booking FROM bookings.tickets
	) b1
left join (
	SELECT book_ref, passenger_id, passenger_name, count(passenger_id) over (partition by book_ref) as num_in_booking FROM bookings.tickets
	) b2 on b1.passenger_id = b2.passenger_id
WHERE b1.book_ref != b2.book_ref
and b1.num_in_booking = b2.num_in_booking
and b1.num_in_booking = (SELECT count(ticket_no) as bookings FROM bookings.tickets b group by book_ref
order by count(ticket_no) desc limit 1);

--4.Вывести номера брони и контактную информацию по пассажирам в брони (passenger_id, passenger_name, contact_data) с количеством людей в брони = 3

INSERT INTO results
select 4, concat(book_ref,'|',passenger_id,'|',passenger_name,'|', contact_data) as info
	from tickets
	where book_ref in  
	(select 
	book_ref
	from tickets
	group by book_ref
	having count(passenger_id) = 3);

--5.	Вывести максимальное количество перелётов на бронь
INSERT INTO results
select 5, count(b.flight_id) from tickets a
left join ticket_flights b on a.ticket_no = b.ticket_no
group by a.book_ref 
order by count(b.flight_id) desc
limit 1;

--6.	Вывести максимальное количество перелётов на пассажира в одной брони

INSERT INTO results
select 6, count(b.flight_id)  from tickets a
left join ticket_flights b on a.ticket_no = b.ticket_no
group by a.book_ref, a.passenger_id
order by count(b.flight_id) desc
limit 1;

--7.	Вывести максимальное количество перелётов на пассажира

INSERT INTO results
select 7, count(b.flight_id)  from tickets a
left join ticket_flights b on a.ticket_no = b.ticket_no
group by a.passenger_id
order by count(b.flight_id) desc
limit 1;

--8.	Вывести контактную информацию по пассажиру(ам) (passenger_id, passenger_name, contact_data) 
--и общие траты на билеты, для пассажира потратившему минимальное количество денег на перелеты

INSERT INTO results
select 8,
concat(a.passenger_id,'|',a.passenger_name,'|', a.contact_data, '|',sum(b.total_amount))
from tickets a left join bookings b on a.book_ref = b.book_ref
group by a.passenger_id, a.passenger_name, a.contact_data
having sum(b.total_amount) = ( select MIN(b.total_amount) from tickets a 
						left join bookings b on a.book_ref = b.book_ref
						) ;
					
--9.	Вывести контактную информацию по пассажиру(ам) (passenger_id, passenger_name, contact_data) и общее время в полётах, 
--для пассажира, который провёл максимальное время в полётах
					
INSERT INTO results
select 9, concat(passenger_id, '|', passenger_name, '|', contact_data, '|', sum_duration)
from
	(select passenger_id, passenger_name, contact_data, sum(actual_duration) sum_duration,
	rank() over(order by sum(actual_duration) desc) rank_sum_duration
	from tickets a
	join ticket_flights using(ticket_no)
	join flights_v using(flight_id)
	WHERE actual_duration is not null
	group by ticket_no) b
WHERE rank_sum_duration = 1
order by passenger_id, passenger_name, contact_data;

--10.	Вывести город(а) с количеством аэропортов больше одного

INSERT INTO results
select 10, city from Airports
group by city
having count(distinct airport_code)>1;

--11.	Вывести город(а), у которого самое меньшее количество городов прямого сообщения

INSERT INTO results
select 11, a.city from airports a 
left join flights b
on a.airport_code = b.departure_airport
group by a.city
having  count(distinct b.arrival_airport) = 1 

--12.	Вывести пары городов, у которых нет прямых сообщений исключив реверсные дубликаты

INSERT INTO results
SELECT 12, concat(f.airoport_dep, '|', f.airoport_arr)
FROM
	(
	SELECT z.airoport_dep
		  ,z.airoport_arr
	FROM
		(
		SELECT a.city as airoport_dep, b.city as airoport_arr
		FROM bookings.airports a
			cross join bookings.airports b
		except
		SELECT distinct departure_city, arrival_city
		FROM bookings.flights_v
		) as z
	WHERE z.airoport_dep <= z.airoport_arr
	union
	SELECT z.airoport_arr
		  ,z.airoport_arr
	FROM
		(
		SELECT a.city as airoport_dep, b.city as airoport_arr
		FROM bookings.airports a
			cross join bookings.airports b
		except
		SELECT distinct departure_city, arrival_city
		FROM bookings.flights_v
		) as z
	WHERE z.airoport_dep > z.airoport_arr
	) as f
WHERE f.airoport_dep != f.airoport_arr
order by f.airoport_dep, f.airoport_arr;

--13.	Вывести города, до которых нельзя добраться без пересадок из Москвы?

INSERT INTO results
SELECT distinct 13, departure_city
FROM routes
WHERE departure_city != 'Москва'
	and departure_city not in (
		SELECT arrival_city FROM routes
		WHERE departure_city = 'Москва');
		
--14.	Вывести модель самолета, который выполнил больше всего рейсов
	
INSERT INTO results
SELECT 14, a.model
FROM flights f
	left join aircrafts a
		on f.aircraft_code = a.aircraft_code
WHERE f.status = 'Arrived'
	or f.status = 'Departed'
group by a.model
order by count(*) desc
limit 1;

--15.	Вывести модель самолета, который перевез больше всего пассажиров

INSERT INTO results
SELECT 15, a.model
FROM bookings.flights f
	left join bookings.aircrafts a
		on f.aircraft_code = a.aircraft_code
	right join bookings.ticket_flights tf
		on f.flight_id = tf.flight_id
	left join bookings.tickets t
		on t.ticket_no = tf.ticket_no
WHERE f.status = 'Arrived'
	or f.status = 'Departed'
group by a.model
order by count(t.passenger_id) desc
limit 1;

--16.Вывести отклонение в минутах суммы запланированного времени перелета
-- от фактического по всем перелётам

INSERT INTO results
SELECT 16, cast(extract(epoch FROM sum((actual_arrival - actual_departure) - (scheduled_arrival - scheduled_departure)))/60 as int)
FROM flights
WHERE actual_arrival is not null;

--17.	Вывести города, в которые осуществлялся перелёт из Санкт-Петербурга 2017-08-11

INSERT INTO results
SELECT distinct 17,
	arrival_city as response
FROM flights_v f
WHERE departure_city = 'Санкт-Петербург'
and date_trunc('day',actual_departure_local) = '2017-08-11'
order by 1,2;

--18.	Вывести перелёт(ы) с максимальной стоимостью всех билетов

INSERT INTO results
SELECT 18, f.flight_id
FROM bookings.flights f
inner join ticket_flights tf on f.flight_id = tf.flight_id
group by f.flight_id
having sum(tf.amount) =
					(SELECT max(summa)
					FROM
						(SELECT sum(tf.amount) as summa
						FROM bookings.flights f
							inner join bookings.ticket_flights tf
								on f.flight_id = tf.flight_id
						group by f.flight_id
						) as f);


	