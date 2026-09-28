with source as (

    select * from {{ source('olist_raw', 'order_reviews') }}

),

renamed as (

    select
        review_id,
        order_id,
        cast(review_score as integer)              as review_score,
        -- Decisão: texto vazio vira NULL, para "sem comentário" ter uma única
        -- representação (a fonte mistura string vazia e nulo).
        nullif(trim(review_comment_title), '')     as review_comment_title,
        nullif(trim(review_comment_message), '')   as review_comment_message,
        cast(review_creation_date as timestamp)    as review_created_at,
        cast(review_answer_timestamp as timestamp) as review_answered_at

    from source

)

select * from renamed
